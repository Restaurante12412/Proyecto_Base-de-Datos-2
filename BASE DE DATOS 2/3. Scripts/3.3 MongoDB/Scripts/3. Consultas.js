// =====================================================================
// MypeInventario - MongoDB
// 3. Consultas de negocio
// Ejecutar despues de "6. Data.js":
//   bash "0. Ejecutar.sh" "3. Consultas.js"
//
// La plantilla pide 1 consulta por integrante: son 5, cada una responde
// una pregunta de negocio de MypeInventario.
//   1. Catalogo activo de una categoria, con variantes y precios
//   2. Los 5 SKU mas vendidos de un periodo
//   3. Ventas por canal en cada dia
//   4. Pedidos abiertos por sucursal y dias que llevan sin entregarse
//   5. Clientes que mas compran, con su canal preferido
// =====================================================================

db = db.getSiblingDB('mype_inventario');

function mostrar(titulo, resultado) {
  print('\n=== ' + titulo + ' ===');
  printjson(resultado);
}


// ---------------------------------------------------------------------
// CONSULTA 1
// Integrante responsable: (completar)
// Pregunta de negocio: que productos activos de la categoria "Polos"
//   ofrece el negocio, y con que variantes y precios?
// Justificacion: es la consulta del catalogo en caja y en la tienda en
//   linea. Como la categoria y las variantes estan embebidas, se responde
//   leyendo una sola coleccion, sin uniones.
// Indice que usa: ix_productos_categoria (categoria.id_categoria).
// ---------------------------------------------------------------------
mostrar('1. Catalogo activo de la categoria Polos',
  db.productos_catalogo.find(
    { id_negocio: 1, 'categoria.id_categoria': 1, estado: 'ACTIVO' },
    { _id: 0, nombre: 1, marca: 1,
      'variantes.codigo_sku': 1, 'variantes.talla': 1,
      'variantes.color': 1, 'variantes.precio_venta': 1 }
  ).sort({ nombre: 1 }).toArray()
);


// ---------------------------------------------------------------------
// CONSULTA 2
// Integrante responsable: (completar)
// Pregunta de negocio: cuales fueron los 5 SKU mas vendidos entre el 10
//   y el 12 de noviembre, en unidades y en importe?
// Justificacion: indica que productos reponer primero. $unwind separa
//   las lineas de cada venta y $group las acumula por SKU; no se cuentan
//   las ventas anuladas.
// Indice que usa: ix_ventas_sku (items.id_sku) y el filtro por fecha.
// ---------------------------------------------------------------------
mostrar('2. Los 5 SKU mas vendidos del periodo',
  db.ventas_documento.aggregate([
    { $match: { estado: 'REGISTRADA',
                fecha_venta: { $gte: ISODate('2026-11-10T00:00:00-05:00'),
                               $lt:  ISODate('2026-11-13T00:00:00-05:00') } } },
    { $unwind: '$items' },
    { $group: { _id: { id_sku: '$items.id_sku', producto: '$items.nombre_producto' },
                unidades: { $sum: '$items.cantidad' },
                importe:  { $sum: '$items.subtotal' },
                ventas:   { $sum: 1 } } },
    { $sort: { unidades: -1, importe: -1 } },
    { $limit: 5 },
    { $project: { _id: 0, id_sku: '$_id.id_sku', producto: '$_id.producto',
                  unidades: 1, importe: 1, ventas: 1 } }
  ]).toArray()
);


// ---------------------------------------------------------------------
// CONSULTA 3
// Integrante responsable: (completar)
// Pregunta de negocio: cuanto se vendio por cada canal en cada dia?
// Justificacion: compara la tienda fisica con WhatsApp y el marketplace
//   para decidir donde invertir. $dateToString agrupa por dia en la hora
//   de Lima; una venta sin canal se muestra como "Sin canal".
// Indice que usa: ix_ventas_canal (canal.id_canal).
// ---------------------------------------------------------------------
mostrar('3. Ventas por canal y dia',
  db.ventas_documento.aggregate([
    { $match: { estado: 'REGISTRADA' } },
    { $group: { _id: { dia: { $dateToString: { format: '%Y-%m-%d', date: '$fecha_venta',
                                                timezone: 'America/Lima' } },
                       canal: { $ifNull: ['$canal.nombre', 'Sin canal'] } },
                ventas:  { $sum: 1 },
                importe: { $sum: '$total' } } },
    { $sort: { '_id.dia': 1, importe: -1 } },
    { $project: { _id: 0, dia: '$_id.dia', canal: '$_id.canal', ventas: 1, importe: 1 } }
  ]).toArray()
);


// ---------------------------------------------------------------------
// CONSULTA 4
// Integrante responsable: (completar)
// Pregunta de negocio: que pedidos siguen abiertos (pendientes o
//   confirmados) en cada sucursal y cuantos dias llevan sin entregarse?
// Justificacion: permite priorizar los pedidos mas atrasados. $dateDiff
//   calcula los dias transcurridos y $size cuenta los cambios de estado
//   guardados en el historial embebido.
// Indice que usa: ix_pedidos_sucursal_estado (id_sucursal, estado_actual).
// ---------------------------------------------------------------------
mostrar('4. Pedidos abiertos por sucursal',
  db.pedidos_seguimiento.aggregate([
    { $match: { estado_actual: { $in: ['PENDIENTE', 'CONFIRMADO'] } } },
    { $project: { _id: 0, id_pedido: '$_id', id_sucursal: 1, id_cliente: 1,
                  estado_actual: 1, total: 1,
                  dias_abierto: { $dateDiff: { startDate: '$fecha_pedido',
                                               endDate: '$$NOW', unit: 'day' } },
                  cambios_de_estado: { $size: '$historial_estados' } } },
    { $sort: { id_sucursal: 1, dias_abierto: -1 } }
  ]).toArray()
);


// ---------------------------------------------------------------------
// CONSULTA 5
// Integrante responsable: (completar)
// Pregunta de negocio: quienes son los 3 clientes que mas compran y cual
//   es su canal preferido?
// Justificacion: identifica a los mejores clientes para campanas de
//   fidelizacion. $lookup trae el perfil del cliente (referencia a
//   clientes_perfil); las ventas sin cliente no se cuentan.
// Indice que usa: ix_ventas_cliente (id_cliente) y el _id de clientes_perfil.
// ---------------------------------------------------------------------
mostrar('5. Clientes que mas compran',
  db.ventas_documento.aggregate([
    { $match: { estado: 'REGISTRADA', id_cliente: { $exists: true } } },
    { $group: { _id: '$id_cliente',
                compras: { $sum: 1 },
                importe: { $sum: '$total' },
                ultima_compra: { $max: '$fecha_venta' } } },
    { $sort: { importe: -1 } },
    { $limit: 3 },
    { $lookup: { from: 'clientes_perfil', localField: '_id',
                 foreignField: '_id', as: 'cliente' } },
    { $unwind: '$cliente' },
    { $project: { _id: 0, id_cliente: '$_id',
                  cliente: { $concat: ['$cliente.nombres', ' ', '$cliente.apellidos'] },
                  canal_preferido: '$cliente.preferencias.canal_preferido',
                  compras: 1, importe: 1, ultima_compra: 1 } }
  ]).toArray()
);
