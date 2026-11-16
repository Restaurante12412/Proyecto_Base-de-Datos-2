// =====================================================================
// MypeInventario - MongoDB
// 1. Base de datos y colecciones
// Ejecutar con el administrador (ver "0. Ejecutar.sh"):
//   bash "0. Ejecutar.sh" "1. Colecciones.js"
//
// Base de datos: mype_inventario
// Colecciones (5), segun la hoja "MongoDB" de 2.2 Diccionario_datos.xlsx:
//   1. productos_catalogo
//   2. clientes_perfil
//   3. ventas_documento
//   4. pedidos_seguimiento
//   5. promociones_campanas
//
// Cada coleccion se crea con un validador ($jsonSchema) que exige los
// campos obligatorios y los tipos BSON del diccionario, y con los indices
// que el diccionario indica en la columna "Indice".
//
// Tipos al insertar:
//   Int64      -> Long(...); el validador tambien acepta Int32, que es
//                 como mongosh guarda un entero escrito sin Long().
//   Decimal128 -> Decimal128("12.50"); un numero simple (12.5) se rechaza.
//   Date       -> ISODate("2026-11-12T10:00:00Z") o new Date().
// Los campos opcionales se omiten cuando no hay dato (no se envian en null).
// =====================================================================

db = db.getSiblingDB('mype_inventario');


// ---------------------------------------------------------------------
// 1. productos_catalogo
//    Catálogo de productos: cada documento reúne el producto, su
//    categoría, sus variantes SKU y los códigos de barras de cada
//    variante.
//    Embebido   : categoria, variantes, atributos
//    Referencias: id_negocio
// ---------------------------------------------------------------------
db.createCollection('productos_catalogo', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['_id', 'id_negocio', 'nombre', 'estado', 'categoria', 'variantes'],
      properties: {
        _id:         { bsonType: ['long', 'int'], description: 'Identificador del producto.' },
        id_negocio:  { bsonType: ['long', 'int'], description: 'Negocio dueño del catálogo (Oracle.Negocio).' },
        nombre:      { bsonType: 'string', description: 'Nombre del producto.' },
        descripcion: { bsonType: 'string', description: 'Descripción del producto.' },
        marca:       { bsonType: 'string', description: 'Marca del producto.' },
        estado:      { bsonType: 'string', enum: ['ACTIVO', 'INACTIVO'], description: 'Estado del producto (ACTIVO / INACTIVO).' },
        categoria: {
          bsonType: 'object',
          description: 'Categoría a la que pertenece el producto.',
          required: ['id_categoria', 'nombre'],
          properties: {
            id_categoria: { bsonType: ['long', 'int'], description: 'Identificador de la categoría.' },
            nombre:       { bsonType: 'string', description: 'Nombre de la categoría.' },
            descripcion:  { bsonType: 'string', description: 'Descripción de la categoría.' }
          }
        },
        variantes: {
          bsonType: 'array',
          minItems: 1,
          description: 'Variantes (SKU) del producto; al menos una.',
          items: {
            bsonType: 'object',
            required: ['id_sku', 'codigo_sku', 'precio_venta', 'estado'],
            properties: {
              id_sku:         { bsonType: ['long', 'int'], description: 'Identificador del SKU; es la llave que usan las demás colecciones y Cassandra.' },
              codigo_sku:     { bsonType: 'string', description: 'Código comercial del SKU.' },
              talla:          { bsonType: 'string', description: 'Talla de la variante.' },
              color:          { bsonType: 'string', description: 'Color de la variante.' },
              precio_venta:   { bsonType: 'decimal', description: 'Precio de venta unitario.' },
              precio_compra:  { bsonType: 'decimal', description: 'Precio de compra unitario.' },
              estado:         { bsonType: 'string', enum: ['ACTIVO', 'INACTIVO'], description: 'Estado de la variante.' },
              codigos_barras: {
                bsonType: 'array',
                description: 'Códigos de barras de la variante.',
                items: {
                  bsonType: 'object',
                  required: ['codigo', 'tipo_codigo', 'estado'],
                  properties: {
                    codigo:      { bsonType: 'string', description: 'Código de barras (lectura en caja).' },
                    tipo_codigo: { bsonType: 'string', description: 'Tipo de código (EAN13, UPC, etc.).' },
                    estado:      { bsonType: 'string', enum: ['ACTIVO', 'INACTIVO'], description: 'Estado del código de barras.' }
                  }
                }
              }
            }
          }
        },
        atributos: {
          bsonType: 'object',
          description: 'Atributos propios del rubro (material, composición, etc.); cada producto puede tener campos distintos.'
        }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

db.productos_catalogo.createIndex({ id_negocio: 1 }, { name: 'ix_productos_negocio' });
db.productos_catalogo.createIndex({ nombre: 'text' }, { name: 'tx_productos_nombre', default_language: 'spanish' });
db.productos_catalogo.createIndex({ marca: 1 }, { name: 'ix_productos_marca' });
db.productos_catalogo.createIndex({ 'categoria.id_categoria': 1 }, { name: 'ix_productos_categoria' });
db.productos_catalogo.createIndex({ 'variantes.id_sku': 1 }, { name: 'ux_productos_id_sku', unique: true });
db.productos_catalogo.createIndex({ 'variantes.codigo_sku': 1 }, { name: 'ux_productos_codigo_sku', unique: true });
db.productos_catalogo.createIndex({ 'variantes.codigos_barras.codigo': 1 }, { name: 'ix_productos_codigo_barras' });


// ---------------------------------------------------------------------
// 2. clientes_perfil
//    Perfil del cliente con sus direcciones embebidas y sus
//    preferencias de compra.
//    Embebido   : direcciones, preferencias
//    Referencias: id_negocio, preferencias.categorias_favoritas
// ---------------------------------------------------------------------
db.createCollection('clientes_perfil', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['_id', 'id_negocio', 'nombres'],
      properties: {
        _id:          { bsonType: ['long', 'int'], description: 'Identificador del cliente.' },
        id_negocio:   { bsonType: ['long', 'int'], description: 'Negocio al que pertenece el cliente (Oracle.Negocio).' },
        nombres:      { bsonType: 'string', description: 'Nombres del cliente.' },
        apellidos:    { bsonType: 'string', description: 'Apellidos del cliente.' },
        documento:    { bsonType: 'string', description: 'Documento de identidad.' },
        telefono:     { bsonType: 'string', description: 'Teléfono de contacto.' },
        email:        { bsonType: 'string', description: 'Correo electrónico.' },
        direcciones: {
          bsonType: 'array',
          description: 'Direcciones registradas del cliente.',
          items: {
            bsonType: 'object',
            required: ['id_direccion', 'direccion', 'principal'],
            properties: {
              id_direccion:  { bsonType: ['long', 'int'], description: 'Identificador de la dirección; lo usa pedidos_seguimiento.' },
              direccion:     { bsonType: 'string', description: 'Calle y número.' },
              referencia:    { bsonType: 'string', description: 'Referencia para ubicar la dirección.' },
              distrito:      { bsonType: 'string', description: 'Distrito.' },
              provincia:     { bsonType: 'string', description: 'Provincia.' },
              departamento:  { bsonType: 'string', description: 'Departamento.' },
              codigo_postal: { bsonType: 'string', description: 'Código postal.' },
              principal:     { bsonType: 'bool', description: 'Indica si es la dirección principal (1 = true).' }
            }
          }
        },
        preferencias: {
          bsonType: 'object',
          description: 'Preferencias de compra del cliente.',
          properties: {
            canal_preferido:      { bsonType: 'string', description: 'Canal de venta que más usa el cliente.' },
            categorias_favoritas: { bsonType: 'array', items: { bsonType: ['long', 'int'] }, description: 'Categorías que más compra el cliente.' }
          }
        }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

db.clientes_perfil.createIndex({ id_negocio: 1, documento: 1 }, { name: 'ix_clientes_negocio_documento' });
db.clientes_perfil.createIndex({ email: 1 }, { name: 'ix_clientes_email' });


// ---------------------------------------------------------------------
// 3. ventas_documento
//    Venta completa en un solo documento: cabecera, canal, líneas de
//    detalle y pagos.
//    Embebido   : canal, items, pagos
//    Referencias: id_cliente, id_empleado, id_sucursal, items.id_sku
// ---------------------------------------------------------------------
db.createCollection('ventas_documento', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['_id', 'id_empleado', 'id_sucursal', 'fecha_venta', 'estado', 'items', 'pagos', 'subtotal', 'descuento', 'impuesto', 'total'],
      properties: {
        _id:         { bsonType: ['long', 'int'], description: 'Identificador de la venta; es la misma llave que usan las tablas de Cassandra.' },
        id_cliente:  { bsonType: ['long', 'int'], description: 'Cliente (clientes_perfil._id); nulo en ventas sin cliente.' },
        id_empleado: { bsonType: ['long', 'int'], description: 'Empleado que registró la venta (Oracle.Empleado).' },
        id_sucursal: { bsonType: ['long', 'int'], description: 'Sucursal donde se vendió (Oracle.Sucursal).' },
        fecha_venta: { bsonType: 'date', description: 'Fecha y hora de la venta.' },
        estado:      { bsonType: 'string', enum: ['REGISTRADA', 'ANULADA'], description: 'Estado de la venta.' },
        canal: {
          bsonType: 'object',
          description: 'Canal por el que se originó la venta.',
          required: ['id_canal', 'nombre', 'fecha_registro'],
          properties: {
            id_canal:           { bsonType: ['long', 'int'], description: 'Identificador del canal.' },
            nombre:             { bsonType: 'string', description: 'Nombre del canal.' },
            referencia_externa: { bsonType: 'string', description: 'Referencia de la venta en el canal externo.' },
            fecha_registro:     { bsonType: 'date', description: 'Fecha en que se asoció la venta al canal.' }
          }
        },
        items: {
          bsonType: 'array',
          minItems: 1,
          description: 'Líneas de la venta; al menos una.',
          items: {
            bsonType: 'object',
            required: ['id_sku', 'cantidad', 'precio_unitario', 'descuento', 'subtotal'],
            properties: {
              id_sku:          { bsonType: ['long', 'int'], description: 'SKU vendido (productos_catalogo.variantes.id_sku).' },
              nombre_producto: { bsonType: 'string', description: 'Nombre del producto al momento de la venta.' },
              cantidad:        { bsonType: 'decimal', description: 'Cantidad vendida.' },
              precio_unitario: { bsonType: 'decimal', description: 'Precio unitario aplicado.' },
              descuento:       { bsonType: 'decimal', description: 'Descuento de la línea.' },
              subtotal:        { bsonType: 'decimal', description: 'Subtotal de la línea = cantidad × precio − descuento.' }
            }
          }
        },
        pagos: {
          bsonType: 'array',
          description: 'Pagos con los que se cubrió la venta.',
          items: {
            bsonType: 'object',
            required: ['tipo_pago', 'monto'],
            properties: {
              tipo_pago:  { bsonType: 'string', enum: ['EFECTIVO', 'TARJETA', 'YAPE', 'PLIN', 'TRANSFERENCIA', 'OTRO'], description: 'Forma de pago (efectivo, tarjeta, Yape, etc.).' },
              monto:      { bsonType: 'decimal', description: 'Monto pagado.' },
              referencia: { bsonType: 'string', description: 'Referencia o número de operación.' }
            }
          }
        },
        subtotal:    { bsonType: 'decimal', description: 'Suma de cantidad × precio de las líneas.' },
        descuento:   { bsonType: 'decimal', description: 'Descuento total de la venta.' },
        impuesto:    { bsonType: 'decimal', description: 'IGV (18 %) sobre (subtotal − descuento).' },
        total:       { bsonType: 'decimal', description: 'Total = subtotal − descuento + impuesto.' }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

db.ventas_documento.createIndex({ id_cliente: 1 }, { name: 'ix_ventas_cliente' });
db.ventas_documento.createIndex({ id_sucursal: 1, fecha_venta: 1 }, { name: 'ix_ventas_sucursal_fecha' });
db.ventas_documento.createIndex({ 'canal.id_canal': 1 }, { name: 'ix_ventas_canal' });
db.ventas_documento.createIndex({ 'items.id_sku': 1 }, { name: 'ix_ventas_sku' });


// ---------------------------------------------------------------------
// 4. pedidos_seguimiento
//    Pedido del cliente con sus líneas y el historial de estados
//    embebido para seguir su avance.
//    Embebido   : direccion_entrega, items, historial_estados
//    Referencias: id_cliente, id_sucursal,
//    direccion_entrega.id_direccion, items.id_sku
// ---------------------------------------------------------------------
db.createCollection('pedidos_seguimiento', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['_id', 'id_cliente', 'fecha_pedido', 'estado_actual', 'items', 'subtotal', 'descuento', 'impuesto', 'total', 'historial_estados'],
      properties: {
        _id:               { bsonType: ['long', 'int'], description: 'Identificador del pedido.' },
        id_cliente:        { bsonType: ['long', 'int'], description: 'Cliente que hizo el pedido (clientes_perfil._id).' },
        id_sucursal:       { bsonType: ['long', 'int'], description: 'Sucursal que atiende el pedido (Oracle.Sucursal).' },
        fecha_pedido:      { bsonType: 'date', description: 'Fecha del pedido.' },
        estado_actual:     { bsonType: 'string', enum: ['PENDIENTE', 'CONFIRMADO', 'ANULADO', 'ENTREGADO'], description: 'Estado vigente del pedido.' },
        direccion_entrega: {
          bsonType: 'object',
          description: 'Dirección de entrega elegida para el pedido.',
          required: ['id_direccion', 'direccion'],
          properties: {
            id_direccion: { bsonType: ['long', 'int'], description: 'Dirección del cliente (clientes_perfil.direcciones.id_direccion).' },
            direccion:    { bsonType: 'string', description: 'Dirección al momento del pedido.' }
          }
        },
        items: {
          bsonType: 'array',
          minItems: 1,
          description: 'Líneas del pedido; al menos una.',
          items: {
            bsonType: 'object',
            required: ['id_sku', 'cantidad', 'precio_unitario', 'descuento', 'subtotal'],
            properties: {
              id_sku:          { bsonType: ['long', 'int'], description: 'SKU pedido (productos_catalogo.variantes.id_sku).' },
              cantidad:        { bsonType: 'decimal', description: 'Cantidad pedida.' },
              precio_unitario: { bsonType: 'decimal', description: 'Precio unitario.' },
              descuento:       { bsonType: 'decimal', description: 'Descuento de la línea.' },
              subtotal:        { bsonType: 'decimal', description: 'Subtotal de la línea.' }
            }
          }
        },
        subtotal:          { bsonType: 'decimal', description: 'Subtotal del pedido.' },
        descuento:         { bsonType: 'decimal', description: 'Descuento total.' },
        impuesto:          { bsonType: 'decimal', description: 'Impuesto (IGV).' },
        total:             { bsonType: 'decimal', description: 'Total del pedido.' },
        historial_estados: {
          bsonType: 'array',
          description: 'Cada cambio de estado del pedido, en orden cronológico.',
          items: {
            bsonType: 'object',
            required: ['estado', 'fecha'],
            properties: {
              estado:  { bsonType: 'string', enum: ['PENDIENTE', 'CONFIRMADO', 'ANULADO', 'ENTREGADO'], description: 'Estado al que pasó el pedido.' },
              fecha:   { bsonType: 'date', description: 'Fecha y hora del cambio.' },
              usuario: { bsonType: 'string', description: 'Usuario que hizo el cambio.' }
            }
          }
        }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

db.pedidos_seguimiento.createIndex({ id_cliente: 1 }, { name: 'ix_pedidos_cliente' });
db.pedidos_seguimiento.createIndex({ id_sucursal: 1, estado_actual: 1 }, { name: 'ix_pedidos_sucursal_estado' });
db.pedidos_seguimiento.createIndex({ 'items.id_sku': 1 }, { name: 'ix_pedidos_sku' });


// ---------------------------------------------------------------------
// 5. promociones_campanas
//    Promociones unificadas: reúne la definición comercial de Oracle y
//    los SKU en promoción de PostgreSQL.
//    Embebido   : vigencia, aplica_a
//    Referencias: id_promocion_oracle, id_promocion_pg, id_negocio,
//    aplica_a.id_sku, canales
// ---------------------------------------------------------------------
db.createCollection('promociones_campanas', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['_id', 'id_negocio', 'nombre', 'tipo', 'valor', 'vigencia', 'estado'],
      properties: {
        _id:                 { bsonType: 'objectId', description: 'Identificador del documento.' },
        id_promocion_oracle: { bsonType: ['long', 'int'], description: 'Promoción en Oracle (si se originó allí).' },
        id_promocion_pg:     { bsonType: ['long', 'int'], description: 'Promoción en PostgreSQL (si se originó allí).' },
        id_negocio:          { bsonType: ['long', 'int'], description: 'Negocio que define la promoción (Oracle.Negocio).' },
        nombre:              { bsonType: 'string', description: 'Nombre de la promoción.' },
        descripcion:         { bsonType: 'string', description: 'Descripción de la promoción.' },
        tipo:                { bsonType: 'string', description: 'Tipo de descuento (porcentaje o monto).' },
        valor:               { bsonType: 'decimal', description: 'Valor del descuento.' },
        vigencia: {
          bsonType: 'object',
          description: 'Periodo de vigencia.',
          required: ['fecha_inicio', 'fecha_fin'],
          properties: {
            fecha_inicio: { bsonType: 'date', description: 'Inicio de la promoción.' },
            fecha_fin:    { bsonType: 'date', description: 'Fin de la promoción.' }
          }
        },
        estado:              { bsonType: 'string', description: 'Estado de la promoción.' },
        aplica_a: {
          bsonType: 'array',
          description: 'SKU a los que aplica la promoción.',
          items: {
            bsonType: 'object',
            required: ['id_sku', 'estado'],
            properties: {
              id_sku: { bsonType: ['long', 'int'], description: 'SKU en promoción (productos_catalogo.variantes.id_sku).' },
              estado: { bsonType: 'string', enum: ['ACTIVO', 'INACTIVO'], description: 'Estado de la asignación.' }
            }
          }
        },
        canales:             { bsonType: 'array', items: { bsonType: 'string' }, description: 'Canales de venta donde aplica la promoción.' }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

db.promociones_campanas.createIndex({ id_promocion_oracle: 1 }, { name: 'ux_promociones_id_oracle', unique: true, partialFilterExpression: { id_promocion_oracle: { $exists: true } } });
db.promociones_campanas.createIndex({ id_promocion_pg: 1 }, { name: 'ux_promociones_id_pg', unique: true, partialFilterExpression: { id_promocion_pg: { $exists: true } } });
db.promociones_campanas.createIndex({ id_negocio: 1 }, { name: 'ix_promociones_negocio' });
db.promociones_campanas.createIndex({ 'vigencia.fecha_inicio': 1, 'vigencia.fecha_fin': 1 }, { name: 'ix_promociones_vigencia' });
db.promociones_campanas.createIndex({ estado: 1 }, { name: 'ix_promociones_estado' });
db.promociones_campanas.createIndex({ 'aplica_a.id_sku': 1 }, { name: 'ix_promociones_sku' });


// ---------------------------------------------------------------------
// VERIFICACION: colecciones creadas y sus indices
// ---------------------------------------------------------------------
print('Base de datos: ' + db.getName());
db.getCollectionNames().sort().forEach(function (c) {
  print('- ' + c + ' | indices: ' + db.getCollection(c).getIndexes().map(function (i) { return i.name; }).join(', '));
});
