// =====================================================================
// MypeInventario - MongoDB
// 2. Estado de la replicacion (evidencias para el informe)
// Ejecutar con el administrador, desde la carpeta "3.3 MongoDB/Scripts":
//   bash "0. Ejecutar.sh" "../Replicacion/Scripts/2. Estado_Replicacion.js"
//
// Pregunta de negocio: si se cae el servidor principal de MongoDB, hay
// copias al dia del catalogo, los clientes, las ventas y los pedidos, y
// cuanto retraso tienen?
//
// Muestra:
//   1. Configuracion del replica set (nodos y prioridades)
//   2. Rol y salud de cada nodo (1 PRIMARY y 2 SECONDARY)
//   3. Retraso de cada secundario respecto al primario
//   4. Tamano y ventana del oplog (el registro que copian los secundarios)
//   5. Nivel de confirmacion de escritura por defecto
// =====================================================================

print('\n=== 1. Configuracion del replica set ===');
var conf = rs.conf();
print('Replica set: ' + conf._id + ' | nodos: ' + conf.members.length);
conf.members.forEach(function (m) {
  print('  ' + m.host + '  prioridad=' + m.priority + '  votos=' + m.votes);
});

print('\n=== 2. Rol y salud de cada nodo ===');
var st = rs.status();
var primario = null;
st.members.forEach(function (m) {
  if (m.stateStr === 'PRIMARY') { primario = m; }
  print('  ' + m.name + '  ' + m.stateStr + '  salud=' + m.health +
        (m.syncSourceHost ? '  copia de: ' + m.syncSourceHost : ''));
});

print('\n=== 3. Retraso de los secundarios (segundos) ===');
st.members.forEach(function (m) {
  if (m.stateStr === 'SECONDARY' && primario) {
    var retraso = (primario.optimeDate.getTime() - m.optimeDate.getTime()) / 1000;
    print('  ' + m.name + '  ultima operacion aplicada: ' + m.optimeDate.toISOString() +
          '  retraso: ' + retraso + ' s');
  }
});
// Los secundarios aplican las operaciones despues de que el primario las
// confirmo: por eso la replicacion es asincronica y el retraso puede ser > 0.

print('\n=== 4. Oplog ===');
rs.printReplicationInfo();

print('\n=== 5. Confirmacion de escritura por defecto ===');
printjson(db.adminCommand({ getDefaultRWConcern: 1 }).defaultWriteConcern);
// Para que una escritura se confirme solo con el primario (asincronica pura)
// se indica en la operacion:  { writeConcern: { w: 1 } }
