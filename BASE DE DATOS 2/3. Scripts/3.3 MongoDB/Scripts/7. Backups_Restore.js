// =====================================================================
// MypeInventario - MongoDB
// 7. Backups y Restore (mongodump / mongorestore) - verificacion
//
// Pregunta de negocio: si se pierde o se dana la base de MongoDB, se
// puede recuperar el catalogo, los clientes, las ventas y los pedidos, y
// con cuanta informacion perdida como maximo?
//
// ESTRATEGIA
//   Tipo       : logico, base completa mype_inventario (5 colecciones,
//                sus indices y validadores), en un solo archivo comprimido.
//   Frecuencia : diario, y uno adicional antes de cada entrega.
//   Retencion  : 7 dias; se eliminan los archivos mas antiguos.
//   Ubicacion  : volumen Docker mype_mongo_backups (/backups dentro del
//                contenedor mype-mongo1) + copia en la carpeta
//                "4. Backups/MongoDB" del repositorio y en la nube.
//   Validacion : cada backup se restaura en la base de pruebas
//                mype_inventario_restore y se comparan colecciones y documentos.
//
// Los comandos de respaldo y restauracion (mongodump / mongorestore) se
// ejecutan paso a paso con "7. Backups_Restore.sh", que tambien lanza
// este archivo para la verificacion:
//   bash "0. Ejecutar.sh" "7. Backups_Restore.js"
// =====================================================================


// ---------------------------------------------------------------------
// VERIFICACION
//    Compara colecciones, documentos e indices de la base original y de
//    la restaurada; deben ser iguales.
// ---------------------------------------------------------------------
function resumen(nombreBase) {
  var base = db.getSiblingDB(nombreBase);
  var r = {};
  base.getCollectionNames().sort().forEach(function (c) {
    r[c] = { documentos: base.getCollection(c).countDocuments({}),
             indices: base.getCollection(c).getIndexes().length };
  });
  return r;
}

var original   = resumen('mype_inventario');
var restaurada = resumen('mype_inventario_restore');

print('\nColeccion                 original (docs/indices)   restaurada (docs/indices)');
Object.keys(original).forEach(function (c) {
  var o = original[c];
  var t = restaurada[c] || { documentos: 0, indices: 0 };
  var igual = o.documentos === t.documentos && o.indices === t.indices;
  print(c.padEnd(26) + (o.documentos + ' / ' + o.indices).padEnd(26) +
        (t.documentos + ' / ' + t.indices).padEnd(22) + (igual ? 'OK' : 'DIFERENTE'));
});
print('\nColecciones: original ' + Object.keys(original).length +
      ', restaurada ' + Object.keys(restaurada).length);
