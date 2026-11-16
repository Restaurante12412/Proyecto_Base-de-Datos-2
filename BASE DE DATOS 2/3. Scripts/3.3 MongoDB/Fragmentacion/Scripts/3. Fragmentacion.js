// =====================================================================
// MypeInventario - MongoDB
// 3. Fragmentacion horizontal (sharding) de ventas_documento
// Lo ejecuta "2. Fragmentacion.sh" en dos momentos, segun la variable de
// entorno PASO que le pasa al contenedor:
//   PASO = 'fragmentar'  antes de cargar los datos
//   PASO = 'evidencias'  despues de cargarlos
//
// Pregunta de negocio: cada sucursal consulta casi siempre sus propias
// ventas; como se reparten las ventas entre servidores para que esa
// consulta lea un solo fragmento y la carga de escritura se distribuya?
//
// CRITERIO: id_sucursal, la misma clave de ubicacion que usa la
//   fragmentacion de PostgreSQL (Inventario) y de Oracle (Venta).
// ESQUEMA: fragmentacion por HASH de id_sucursal entre 2 shards.
//   - Todas las ventas de una sucursal quedan en el mismo shard, asi que
//     la consulta por sucursal se dirige a un solo fragmento.
//   - El hash reparte las sucursales de forma pareja; con una clave por
//     rango, las sucursales con ids consecutivos caerian todas en el
//     mismo shard mientras haya pocos datos.
// Las otras 4 colecciones no se fragmentan: quedan en el shard primario
// de la base (catalogo, clientes, pedidos y promociones son mas pequenas
// y se consultan por otras claves).
// =====================================================================

var base = db.getSiblingDB('mype_inventario');

var PASO = process.env.PASO;
if (PASO !== 'fragmentar' && PASO !== 'evidencias') {
  throw new Error('Indicar el paso con la variable de entorno PASO: fragmentar o evidencias (ver "2. Fragmentacion.sh").');
}


// ---------------------------------------------------------------------
// PASO 'fragmentar': habilitar la base y fragmentar la coleccion vacia
// ---------------------------------------------------------------------
if (PASO === 'fragmentar') {
  if (base.ventas_documento.countDocuments({}) > 0) {
    throw new Error('ventas_documento ya tiene documentos; debe fragmentarse vacia.');
  }
  printjson(sh.enableSharding('mype_inventario'));
  // Con la coleccion vacia, MongoDB crea el indice hash de la clave y
  // reparte los fragmentos iniciales entre los shards.
  printjson(sh.shardCollection('mype_inventario.ventas_documento', { id_sucursal: 'hashed' }));

  print('\nClave de fragmentacion registrada:');
  printjson(db.getSiblingDB('config').collections.findOne(
    { _id: 'mype_inventario.ventas_documento' }, { key: 1, unique: 1 }));
}


// ---------------------------------------------------------------------
// PASO 'evidencias': reparto de los datos y comportamiento de las consultas
// ---------------------------------------------------------------------
if (PASO === 'evidencias') {

  print('\n=== 1. Shards del cluster ===');
  db.adminCommand({ listShards: 1 }).shards.forEach(function (s) { print('  ' + s._id + '  ' + s.host); });

  print('\n=== 2. Documentos de ventas_documento por shard ===');
  base.ventas_documento.getShardDistribution();

  print('\n=== 3. Sucursales y ventas en cada shard ===');
  base.ventas_documento.aggregate([
    { $group: { _id: '$id_sucursal', ventas: { $sum: 1 } } },
    { $sort: { _id: 1 } }
  ]).toArray().forEach(function (r) {
    var plan = base.ventas_documento.find({ id_sucursal: r._id }).explain().queryPlanner.winningPlan;
    var shard = plan.shards && plan.shards.length === 1 ? plan.shards[0].shardName : '(varios)';
    print('  sucursal ' + r._id + ': ' + r.ventas + ' ventas -> ' + shard);
  });

  print('\n=== 4. Sin perdida de documentos (deben coincidir) ===');
  var total = base.ventas_documento.countDocuments({});
  var suma = 0;
  db.adminCommand({ listShards: 1 }).shards.forEach(function (s) {
    var n = base.ventas_documento.aggregate([{ $collStats: { count: {} } }]).toArray()
      .filter(function (c) { return c.shard === s._id; })
      .reduce(function (a, c) { return a + c.count; }, 0);
    print('  ' + s._id + ': ' + n);
    suma += n;
  });
  print('  total por shards: ' + suma + ' | total de la coleccion: ' + total);

  print('\n=== 5. Consulta CON la clave (id_sucursal = 3): un solo shard ===');
  var p1 = base.ventas_documento.find({ id_sucursal: 3 }).explain().queryPlanner.winningPlan;
  print('  etapa: ' + p1.stage + ' | shards consultados: ' + p1.shards.map(function (s) { return s.shardName; }).join(', '));
  // Esperado: SINGLE_SHARD y un solo shard

  print('\n=== 6. Consulta SIN la clave (estado = REGISTRADA): todos los shards ===');
  var p2 = base.ventas_documento.find({ estado: 'REGISTRADA' }).explain().queryPlanner.winningPlan;
  print('  etapa: ' + p2.stage + ' | shards consultados: ' + p2.shards.map(function (s) { return s.shardName; }).join(', '));
  // Esperado: SHARD_MERGE y los 2 shards

  print('\n=== 7. Colecciones no fragmentadas (quedan en el shard primario) ===');
  ['productos_catalogo', 'clientes_perfil', 'pedidos_seguimiento', 'promociones_campanas'].forEach(function (c) {
    var st = base.getCollection(c).stats();
    print('  ' + c + ': ' + base.getCollection(c).countDocuments({}) + ' documentos | fragmentada: ' + (st.sharded === true));
  });
}
