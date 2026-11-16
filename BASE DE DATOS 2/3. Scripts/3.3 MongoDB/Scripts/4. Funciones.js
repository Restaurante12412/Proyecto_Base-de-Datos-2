// =====================================================================
// MypeInventario - MongoDB
// 4. Funciones
// MongoDB no tiene procedimientos almacenados como PostgreSQL u Oracle;
// su equivalente son funciones JavaScript que se cargan en mongosh.
//
// Cargar las funciones y dejar abierta la consola (despues de "6. Data.js"):
//   bash "0. Ejecutar.sh" "4. Funciones.js" --shell
// y luego llamarlas en esa consola, por ejemplo:
//   fn_buscar_por_codigo_barras("7750000000076")
//
// La plantilla pide 1 funcion por integrante: son 5, cada una responde
// una necesidad del negocio.
//   1. fn_buscar_por_codigo_barras   que producto corresponde a un codigo leido en caja
//   2. fn_precio_con_promocion       cuanto cuesta hoy un SKU con su promocion vigente
//   3. sp_cambiar_estado_pedido      pasar un pedido a su siguiente estado dejando historial
//   4. fn_resumen_ventas_sucursal    cuanto vendio una sucursal en un periodo
//   5. sp_agregar_direccion_cliente  registrar una nueva direccion de entrega
// =====================================================================

function mype() {
  return db.getSiblingDB('mype_inventario');
}


// ---------------------------------------------------------------------
// 1. fn_buscar_por_codigo_barras(codigo)
//    Integrante responsable: (completar)
//    Pregunta de negocio: que producto y que variante corresponde al
//    codigo de barras que se acaba de leer en caja, y cual es su precio?
//    Devuelve el producto con solo la variante de ese codigo, o null.
//    Usa el indice ix_productos_codigo_barras.
// ---------------------------------------------------------------------
globalThis.fn_buscar_por_codigo_barras = function (codigo) {
  var r = mype().productos_catalogo.aggregate([
    { $match: { 'variantes.codigos_barras.codigo': codigo } },
    { $unwind: '$variantes' },
    { $match: { 'variantes.codigos_barras.codigo': codigo } },
    { $project: { _id: 0, id_producto: '$_id', producto: '$nombre', marca: 1,
                  id_sku: '$variantes.id_sku', codigo_sku: '$variantes.codigo_sku',
                  talla: '$variantes.talla', color: '$variantes.color',
                  precio_venta: '$variantes.precio_venta', estado: '$variantes.estado' } }
  ]).toArray();
  return r.length > 0 ? r[0] : null;
};


// ---------------------------------------------------------------------
// 2. fn_precio_con_promocion(idSku, fecha)
//    Integrante responsable: (completar)
//    Pregunta de negocio: cuanto se le cobra hoy al cliente por un SKU,
//    considerando la promocion vigente que mas le conviene?
//    fecha es opcional (por defecto, el momento actual).
//    Devuelve precio de lista, promocion aplicada y precio final.
//    Usa los indices ux_productos_id_sku e ix_promociones_sku.
// ---------------------------------------------------------------------
globalThis.fn_precio_con_promocion = function (idSku, fecha) {
  var cuando = fecha || new Date();
  var p = mype().productos_catalogo.findOne(
    { 'variantes.id_sku': idSku },
    { nombre: 1, variantes: { $elemMatch: { id_sku: idSku } } });
  if (!p) { throw new Error('No existe el SKU ' + idSku); }

  var precio = Number(p.variantes[0].precio_venta.toString());
  var promos = mype().promociones_campanas.find({
    estado: 'ACTIVA',
    'vigencia.fecha_inicio': { $lte: cuando },
    'vigencia.fecha_fin': { $gte: cuando },
    aplica_a: { $elemMatch: { id_sku: idSku, estado: 'ACTIVO' } }
  }).toArray();

  var mejor = null;
  var descuento = 0;
  promos.forEach(function (pr) {
    var valor = Number(pr.valor.toString());
    var d = pr.tipo === 'PORCENTAJE' ? precio * valor / 100 : valor;
    if (d > descuento) { descuento = d; mejor = pr.nombre; }
  });
  if (descuento > precio) { descuento = precio; }

  return {
    id_sku: idSku,
    producto: p.nombre,
    precio_lista: precio.toFixed(2),
    promocion: mejor || 'Sin promocion vigente',
    descuento: descuento.toFixed(2),
    precio_final: (precio - descuento).toFixed(2)
  };
};


// ---------------------------------------------------------------------
// 3. sp_cambiar_estado_pedido(idPedido, nuevoEstado, usuario)
//    Integrante responsable: (completar)
//    Pregunta de negocio: como avanza un pedido y quien lo movio?
//    Cambia el estado solo si la transicion es valida y agrega el cambio
//    al historial embebido, todo en una sola operacion atomica:
//      PENDIENTE  -> CONFIRMADO o ANULADO
//      CONFIRMADO -> ENTREGADO  o ANULADO
//    ENTREGADO y ANULADO son estados finales.
// ---------------------------------------------------------------------
globalThis.sp_cambiar_estado_pedido = function (idPedido, nuevoEstado, usuario) {
  var permitidos = {
    CONFIRMADO: ['PENDIENTE'],
    ENTREGADO:  ['CONFIRMADO'],
    ANULADO:    ['PENDIENTE', 'CONFIRMADO']
  };
  if (!permitidos[nuevoEstado]) {
    throw new Error('Estado no valido: ' + nuevoEstado);
  }
  var cambio = { estado: nuevoEstado, fecha: new Date() };
  if (usuario) { cambio.usuario = usuario; }

  // El filtro incluye el estado actual: si otro usuario ya movio el
  // pedido, no se modifica nada.
  var r = mype().pedidos_seguimiento.updateOne(
    { _id: idPedido, estado_actual: { $in: permitidos[nuevoEstado] } },
    { $set: { estado_actual: nuevoEstado }, $push: { historial_estados: cambio } });

  if (r.modifiedCount === 0) {
    var p = mype().pedidos_seguimiento.findOne({ _id: idPedido }, { estado_actual: 1 });
    if (!p) { throw new Error('No existe el pedido ' + idPedido); }
    throw new Error('El pedido ' + idPedido + ' esta ' + p.estado_actual +
                    ' y no puede pasar a ' + nuevoEstado);
  }
  return mype().pedidos_seguimiento.findOne(
    { _id: idPedido }, { _id: 1, estado_actual: 1, historial_estados: 1 });
};


// ---------------------------------------------------------------------
// 4. fn_resumen_ventas_sucursal(idSucursal, desde, hasta)
//    Integrante responsable: (completar)
//    Pregunta de negocio: cuantas ventas hizo una sucursal en un periodo,
//    cuanto vendio y cual fue su ticket promedio?
//    desde y hasta son fechas (hasta no se incluye). No cuenta anuladas.
//    Usa el indice ix_ventas_sucursal_fecha.
// ---------------------------------------------------------------------
globalThis.fn_resumen_ventas_sucursal = function (idSucursal, desde, hasta) {
  var r = mype().ventas_documento.aggregate([
    { $match: { id_sucursal: idSucursal, estado: 'REGISTRADA',
                fecha_venta: { $gte: desde, $lt: hasta } } },
    { $group: { _id: '$id_sucursal',
                ventas: { $sum: 1 },
                importe: { $sum: '$total' },
                ticket_promedio: { $avg: '$total' },
                venta_mayor: { $max: '$total' } } },
    { $project: { _id: 0, id_sucursal: '$_id', ventas: 1, importe: 1,
                  ticket_promedio: { $round: ['$ticket_promedio', 2] }, venta_mayor: 1 } }
  ]).toArray();
  return r.length > 0 ? r[0] : { id_sucursal: idSucursal, ventas: 0 };
};


// ---------------------------------------------------------------------
// 5. sp_agregar_direccion_cliente(idCliente, direccion, distrito, esPrincipal)
//    Integrante responsable: (completar)
//    Pregunta de negocio: a que direccion se le entrega el pedido a un
//    cliente que registra una nueva?
//    Agrega la direccion al perfil del cliente. Si es la principal, antes
//    quita la marca a las demas, para que solo haya una principal.
//    El id_direccion es el siguiente al mayor registrado en la coleccion.
// ---------------------------------------------------------------------
globalThis.sp_agregar_direccion_cliente = function (idCliente, direccion, distrito, esPrincipal) {
  var c = mype().clientes_perfil.findOne({ _id: idCliente }, { direcciones: 1 });
  if (!c) { throw new Error('No existe el cliente ' + idCliente); }
  if (!direccion) { throw new Error('La direccion es obligatoria'); }

  var actuales = c.direcciones || [];
  var mayor = mype().clientes_perfil.aggregate([
    { $unwind: '$direcciones' },
    { $group: { _id: null, m: { $max: '$direcciones.id_direccion' } } }
  ]).toArray();
  // El maximo puede llegar como Long (Int64) o como numero simple
  var m = mayor.length > 0 ? mayor[0].m : 0;
  var nuevoId = (m && typeof m.toNumber === 'function' ? m.toNumber() : Number(m)) + 1;

  var principal = esPrincipal === true || actuales.length === 0;
  if (principal && actuales.length > 0) {
    mype().clientes_perfil.updateOne(
      { _id: idCliente }, { $set: { 'direcciones.$[].principal': false } });
  }

  var nueva = { id_direccion: nuevoId, direccion: direccion, principal: principal };
  if (distrito) { nueva.distrito = distrito; }
  mype().clientes_perfil.updateOne({ _id: idCliente }, { $push: { direcciones: nueva } });

  return mype().clientes_perfil.findOne({ _id: idCliente }, { nombres: 1, direcciones: 1 });
};


// ---------------------------------------------------------------------
// EJEMPLOS DE USO (en la consola que deja abierta "0. Ejecutar.sh ... --shell";
// los valores corresponden a los datos de "6. Data.js")
// ---------------------------------------------------------------------
//   fn_buscar_por_codigo_barras("7750000000076")                 // SKU 7
//   fn_precio_con_promocion(67, ISODate("2026-11-15T17:00:00Z")) // con promocion vigente (15 %)
//   fn_precio_con_promocion(7)                                   // sin promocion vigente
//   sp_cambiar_estado_pedido(1, "CONFIRMADO", "jose_callupe")    // PENDIENTE -> CONFIRMADO
//   sp_cambiar_estado_pedido(3, "ANULADO", "jose_callupe")       // debe dar error: ya esta ENTREGADO
//   fn_resumen_ventas_sucursal(1, ISODate("2026-08-01T05:00:00Z"), ISODate("2026-12-01T05:00:00Z"))
//   sp_agregar_direccion_cliente(4, "Av. Arequipa 1520", "Lince", true)

print('Funciones cargadas: fn_buscar_por_codigo_barras, fn_precio_con_promocion, ' +
      'sp_cambiar_estado_pedido, fn_resumen_ventas_sucursal, sp_agregar_direccion_cliente');
