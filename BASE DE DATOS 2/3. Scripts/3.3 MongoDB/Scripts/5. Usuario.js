// =====================================================================
// MypeInventario - MongoDB
// 5. Usuarios, roles y permisos
// Ejecutar con el administrador, despues de "1. Colecciones.js":
//   bash "0. Ejecutar.sh" "5. Usuario.js"
//
// Las contrasenas NO estan en este archivo: mongosh las solicita con
// passwordPrompt() (entrada oculta) al crear cada usuario.
// El replica set tiene la autenticacion activa (keyfile), asi que los
// permisos se aplican desde el primer momento.
//
//   Usuario          Rol
//   ericson_damian   rol_admin_mongo
//   pedro_zavaleta   rol_gestor_catalogo
//   jose_callupe     rol_gestor_ventas
//   keyden_navarro   rol_analista
//   yemima_reyes     rol_auditoria
// Conexion con un usuario (pide su contrasena):
//   USUARIO=yemima_reyes BASE_AUT=mype_inventario bash "0. Ejecutar.sh"
// =====================================================================

db = db.getSiblingDB('mype_inventario');

function col(nombre) {
  return { db: 'mype_inventario', collection: nombre };
}
var LECTURA   = ['find'];
var ESCRITURA = ['find', 'insert', 'update'];
var TOTAL     = ['find', 'insert', 'update', 'remove'];


// ---------------------------------------------------------------------
// 1. ROLES (privilegios minimos por coleccion)
// ---------------------------------------------------------------------

// Administrador: gestiona usuarios, roles e indices; sobre los datos solo lee.
db.createRole({
  role: 'rol_admin_mongo',
  privileges: [
    { resource: { db: 'mype_inventario', collection: '' },
      actions: ['find', 'listCollections', 'listIndexes', 'collStats', 'dbStats',
                'createIndex', 'dropIndex', 'collMod',
                'createUser', 'dropUser', 'createRole', 'dropRole',
                'grantRole', 'revokeRole', 'viewUser', 'viewRole',
                'changePassword'] }
  ],
  roles: []
});

// Gestor de catalogo: mantiene productos y promociones; lee ventas y pedidos.
db.createRole({
  role: 'rol_gestor_catalogo',
  privileges: [
    { resource: col('productos_catalogo'),   actions: TOTAL },
    { resource: col('promociones_campanas'), actions: TOTAL },
    { resource: col('ventas_documento'),     actions: LECTURA },
    { resource: col('pedidos_seguimiento'),  actions: LECTURA }
  ],
  roles: []
});

// Gestor de ventas: registra ventas, pedidos y clientes (sin borrar);
// lee el catalogo y las promociones.
db.createRole({
  role: 'rol_gestor_ventas',
  privileges: [
    { resource: col('ventas_documento'),     actions: ESCRITURA },
    { resource: col('pedidos_seguimiento'),  actions: ESCRITURA },
    { resource: col('clientes_perfil'),      actions: ESCRITURA },
    { resource: col('productos_catalogo'),   actions: LECTURA },
    { resource: col('promociones_campanas'), actions: LECTURA }
  ],
  roles: []
});

// Analista: solo lectura, sin acceso a clientes_perfil (datos personales).
db.createRole({
  role: 'rol_analista',
  privileges: [
    { resource: col('productos_catalogo'),   actions: LECTURA },
    { resource: col('ventas_documento'),     actions: LECTURA },
    { resource: col('pedidos_seguimiento'),  actions: LECTURA },
    { resource: col('promociones_campanas'), actions: LECTURA }
  ],
  roles: []
});

// Auditoria: solo lectura sobre las 5 colecciones.
db.createRole({
  role: 'rol_auditoria',
  privileges: [
    { resource: col('productos_catalogo'),   actions: LECTURA },
    { resource: col('clientes_perfil'),      actions: LECTURA },
    { resource: col('ventas_documento'),     actions: LECTURA },
    { resource: col('pedidos_seguimiento'),  actions: LECTURA },
    { resource: col('promociones_campanas'), actions: LECTURA }
  ],
  roles: []
});


// ---------------------------------------------------------------------
// 2. USUARIOS (uno por integrante, cada uno con su rol)
// ---------------------------------------------------------------------
print('Contrasena para ericson_damian:');
db.createUser({ user: 'ericson_damian', pwd: passwordPrompt(),
                roles: [{ role: 'rol_admin_mongo', db: 'mype_inventario' }] });      // Damian Garay, Ericson Anthony (DBA)
print('Contrasena para pedro_zavaleta:');
db.createUser({ user: 'pedro_zavaleta', pwd: passwordPrompt(),
                roles: [{ role: 'rol_gestor_catalogo', db: 'mype_inventario' }] });  // Zavaleta Timana, Pedro Sebastian
print('Contrasena para jose_callupe:');
db.createUser({ user: 'jose_callupe', pwd: passwordPrompt(),
                roles: [{ role: 'rol_gestor_ventas', db: 'mype_inventario' }] });    // Callupe Torres, Jose Marcelo
print('Contrasena para keyden_navarro:');
db.createUser({ user: 'keyden_navarro', pwd: passwordPrompt(),
                roles: [{ role: 'rol_analista', db: 'mype_inventario' }] });         // Navarro Caysahuana, Keyden Andrew
print('Contrasena para yemima_reyes:');
db.createUser({ user: 'yemima_reyes', pwd: passwordPrompt(),
                roles: [{ role: 'rol_auditoria', db: 'mype_inventario' }] });        // Reyes Anticona, Yemima Milagros


// ---------------------------------------------------------------------
// 3. VERIFICACION (para capturas del informe)
// ---------------------------------------------------------------------
print('\nUsuarios y roles:');
var usuarios = db.getUsers();
(usuarios.users || usuarios).forEach(function (u) {
  print('- ' + u.user + ' -> ' + u.roles.map(function (r) { return r.role; }).join(', '));
});

print('\nPrivilegios por rol:');
var roles = db.getRoles({ showPrivileges: true });
(roles.roles || roles).forEach(function (r) {
  print('- ' + r.role);
  r.privileges.forEach(function (p) {
    print('    ' + (p.resource.collection || '(todas las colecciones)') + ': ' + p.actions.join(', '));
  });
});


// ---------------------------------------------------------------------
// 4. PRUEBAS DE ACCESO (ejecutar conectado con cada usuario)
// ---------------------------------------------------------------------
// yemima_reyes (auditoria):
//   db.ventas_documento.countDocuments({})                          -> permitido
//   db.productos_catalogo.updateOne({ _id: 1 }, { $set: { marca: "X" } })   -> denegado (not authorized)
// keyden_navarro (analista):
//   db.ventas_documento.countDocuments({})                          -> permitido
//   db.clientes_perfil.findOne()                                    -> denegado
// jose_callupe (gestor de ventas):
//   db.pedidos_seguimiento.updateOne({ _id: 5 }, { $set: { id_sucursal: 1 } })  -> permitido
//   db.ventas_documento.deleteOne({ _id: 1 })                       -> denegado
// pedro_zavaleta (gestor de catalogo):
//   db.productos_catalogo.updateOne({ _id: 6 }, { $set: { estado: "ACTIVO" } }) -> permitido
//   db.clientes_perfil.findOne()                                    -> denegado
// ericson_damian (administrador):
//   db.getUsers()                                                   -> permitido
//   db.ventas_documento.deleteOne({ _id: 1 })                       -> denegado
