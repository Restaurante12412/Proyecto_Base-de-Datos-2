-- =====================================================================
-- MypeInventario - ORACLE
-- 6. Data: 500 registros en cada una de las 20 tablas (10.000 en total)
--
-- Ejecutar conectado como MYPE_INVENTARIO, DESPUES de "2. Tablas.sql"
-- y ANTES de "3. Indices.sql" (con F5 / Run Script):
--
-- REQUISITO: las tablas deben estar recien creadas. Las claves usan
-- IDENTITY y este script asume que los ids son 1..500. Si ya se cargo
-- algo (o una carga anterior fallo a medias), el script se detiene con
-- un mensaje; en ese caso recrear el esquema (DROP USER MYPE_INVENTARIO
-- CASCADE y ejecutar los scripts 1 y 2 de nuevo).
--
-- Diseno de los datos
--   * Todo es determinista (sin azar): se puede repetir y obtener lo mismo.
--   * Coherencia entre negocios: la sucursal, el empleado, el cliente, el
--     proveedor, el canal y el SKU de cada operacion pertenecen al mismo
--     negocio.
--   * Cada cabecera tiene exactamente 1 detalle y sus totales cuadran:
--       total = subtotal - descuento + impuesto   (IGV 18 %)
--   * Ventas: sucursales 1..20, ultimos 90 dias; 1 de cada 25 ANULADA.
--   * Casos utiles para las pruebas de los demas scripts:
--       - Cliente 1: negocio 1, documento '12345678' (script de indices)
--       - Venta 1 REGISTRADA; venta 25 ANULADA (sp_anular_venta)
--       - SKU 1 y 2 ACTIVOS; SKU 50 y 100 INACTIVOS (ORA-20015)
--       - Proveedor 1 con 10 compras (reporte de compras)
--       - Ventas sin cliente (mostrador) y pedidos sin sucursal (online)
--   * Sin contrasenas ni datos reales; correos con dominio ficticio.
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET VERIFY OFF
SET DEFINE ON
SET SERVEROUTPUT ON
SET LINESIZE 150

-- Listas de apoyo (valores separados por coma)
DEFINE v_nom    = 'Juan,Maria,Carlos,Rosa,Luis,Ana,Jorge,Carmen,Pedro,Lucia,Miguel,Elena,Jose,Patricia,Victor,Sofia,Diego,Daniela,Fernando,Gabriela'
DEFINE v_ape    = 'Garcia,Rodriguez,Quispe,Flores,Torres,Ramirez,Mendoza,Vargas,Castillo,Rojas,Huaman,Chavez,Salazar,Paredes,Gutierrez,Ramos,Soto,Valdivia,Campos,Aguilar'
DEFINE v_calle  = 'Av. Arequipa,Jr. Union,Av. Brasil,Calle Los Pinos,Av. Javier Prado,Jr. Cusco,Av. La Marina,Calle Las Flores,Av. Universitaria,Jr. Huallaga'
DEFINE v_dist   = 'Miraflores,San Isidro,Surco,La Molina,San Borja,Lince,Jesus Maria,Comas,San Juan de Lurigancho,Villa El Salvador'
DEFINE v_tipoNeg= 'Boutique,Zapateria,Bazar,Tienda de Ropa,Tienda Deportiva,Variedades,Moda Urbana,Calzados'
DEFINE v_cargo  = 'Cajero,Vendedor,Almacenero,Supervisor,Administrador'
DEFINE v_rubro  = 'Textiles,Confecciones,Calzados,Importaciones,Distribuidora'
DEFINE v_cat    = 'Polos,Pantalones,Vestidos,Casacas,Zapatillas,Zapatos,Sandalias,Carteras,Bazar,Accesorios'
DEFINE v_item   = 'Polo,Pantalon jean,Vestido,Casaca,Zapatilla urbana,Zapato de vestir,Sandalia,Cartera,Juego de tazas,Cinturon'
DEFINE v_marca  = 'Topy Top,Denim Lima,Moda Peru,Urban Style,Bata,Calimod,Sandak,Cuerolima,Casa Hogar,Accesorios Lima'
DEFINE v_talla  = 'S,M,L,XL,UNICA'
DEFINE v_color  = 'Negro,Blanco,Rojo,Azul,Verde,Gris'
DEFINE v_canal  = 'Tienda fisica,WhatsApp,Instagram,Facebook,Web,Delivery,Telefono,Marketplace'
DEFINE v_pago   = 'EFECTIVO,TARJETA,YAPE,PLIN,TRANSFERENCIA,OTRO'
DEFINE v_estped = 'PENDIENTE,CONFIRMADO,ENTREGADO,ANULADO'
DEFINE v_tipopr = 'PORCENTAJE,MONTO_FIJO,DOS_POR_UNO,VOLUMEN'


-- ---------------------------------------------------------------------
-- 0. VERIFICACION PREVIA: las 20 tablas deben estar vacias y con sus
--    identidades sin usar (si no, los ids no empezarian en 1).
-- ---------------------------------------------------------------------
DECLARE
  v_identidades NUMBER;
  v_usadas      NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_identidades FROM user_tab_identity_cols;
  IF v_identidades <> 20 THEN
    RAISE_APPLICATION_ERROR(-20100,
      'Se esperaban 20 tablas con IDENTITY y hay ' || v_identidades ||
      '. Conectese como MYPE_INVENTARIO y ejecute antes "2. Tablas.sql".');
  END IF;

  SELECT COUNT(*) INTO v_usadas
  FROM user_tab_identity_cols i
  JOIN user_sequences s ON s.sequence_name = i.sequence_name
  WHERE s.last_number <> 1;
  IF v_usadas > 0 THEN
    RAISE_APPLICATION_ERROR(-20101,
      'Hay ' || v_usadas || ' identidades ya usadas: las tablas no estan recien creadas. ' ||
      'Recree el esquema (DROP USER MYPE_INVENTARIO CASCADE; scripts 1 y 2).');
  END IF;
END;
/


-- ---------------------------------------------------------------------
-- 1. Comerciante (500)
-- ---------------------------------------------------------------------
INSERT INTO Comerciante (nombres, apellidos, documento, telefono, email, fecha_registro)
SELECT REGEXP_SUBSTR('&v_nom', '[^,]+', 1, MOD(g.n-1, 20) + 1),
       REGEXP_SUBSTR('&v_ape', '[^,]+', 1, MOD(g.n*7, 20) + 1),
       TO_CHAR(40000000 + g.n),
       '9' || TO_CHAR(10000000 + g.n*13),
       'comerciante' || g.n || '@mypeinventario.pe',
       TRUNC(SYSDATE) - MOD(g.n*11, 700) - 30
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 2. Negocio (500): un negocio por comerciante
-- ---------------------------------------------------------------------
INSERT INTO Negocio (id_comerciante, nombre, ruc, direccion, telefono, email, fecha_registro)
SELECT g.n,
       REGEXP_SUBSTR('&v_tipoNeg', '[^,]+', 1, MOD(g.n-1, 8) + 1) || ' ' ||
         REGEXP_SUBSTR('&v_ape', '[^,]+', 1, MOD(g.n*3, 20) + 1) || ' ' || g.n,
       '20' || LPAD(g.n, 9, '0'),
       REGEXP_SUBSTR('&v_calle', '[^,]+', 1, MOD(g.n-1, 10) + 1) || ' ' || (100 + g.n) || ', Lima',
       '01' || TO_CHAR(2000000 + g.n*7),
       'negocio' || g.n || '@mypeinventario.pe',
       TRUNC(SYSDATE) - MOD(g.n*9, 600) - 20
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 3. Sucursal (500): negocios 1..50, 10 sucursales cada uno
--    sucursal n -> negocio MOD(n-1,50)+1
-- ---------------------------------------------------------------------
INSERT INTO Sucursal (id_negocio, nombre, direccion, telefono, estado)
SELECT MOD(g.n-1, 50) + 1,
       'Sucursal ' || LPAD(g.n, 3, '0'),
       REGEXP_SUBSTR('&v_calle', '[^,]+', 1, MOD(g.n*3, 10) + 1) || ' ' || (200 + g.n) || ', ' ||
         REGEXP_SUBSTR('&v_dist', '[^,]+', 1, MOD(g.n-1, 10) + 1),
       '01' || TO_CHAR(3000000 + g.n*11),
       CASE WHEN MOD(g.n, 25) = 0 THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 4. Empleado (500): empleado n pertenece a la sucursal n
-- ---------------------------------------------------------------------
INSERT INTO Empleado (id_sucursal, nombres, apellidos, documento, cargo, telefono, email, estado)
SELECT g.n,
       REGEXP_SUBSTR('&v_nom', '[^,]+', 1, MOD(g.n*3, 20) + 1),
       REGEXP_SUBSTR('&v_ape', '[^,]+', 1, MOD(g.n*11, 20) + 1),
       TO_CHAR(50000000 + g.n),
       REGEXP_SUBSTR('&v_cargo', '[^,]+', 1, MOD(g.n-1, 5) + 1),
       '9' || TO_CHAR(20000000 + g.n*17),
       'empleado' || g.n || '@mypeinventario.pe',
       CASE WHEN MOD(g.n, 25) = 0 THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 5. Proveedor (500): proveedor n -> negocio MOD(n-1,50)+1
-- ---------------------------------------------------------------------
INSERT INTO Proveedor (id_negocio, razon_social, ruc, telefono, email, direccion)
SELECT MOD(g.n-1, 50) + 1,
       REGEXP_SUBSTR('&v_rubro', '[^,]+', 1, MOD(g.n-1, 5) + 1) || ' ' ||
         REGEXP_SUBSTR('&v_ape', '[^,]+', 1, MOD(g.n*13, 20) + 1) || ' S.A.C.',
       '20' || TO_CHAR(500000000 + g.n),
       '01' || TO_CHAR(4000000 + g.n*3),
       'proveedor' || g.n || '@mypeinventario.pe',
       REGEXP_SUBSTR('&v_calle', '[^,]+', 1, MOD(g.n*7, 10) + 1) || ' ' || (300 + g.n) || ', ' ||
         REGEXP_SUBSTR('&v_dist', '[^,]+', 1, MOD(g.n*3, 10) + 1)
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 6. CategoriaProducto (500): categoria n -> negocio MOD(n-1,50)+1
-- ---------------------------------------------------------------------
INSERT INTO CategoriaProducto (id_negocio, nombre, descripcion)
SELECT MOD(g.n-1, 50) + 1,
       REGEXP_SUBSTR('&v_cat', '[^,]+', 1, MOD(g.n-1, 10) + 1),
       'Categoria ' || REGEXP_SUBSTR('&v_cat', '[^,]+', 1, MOD(g.n-1, 10) + 1) ||
         ' del negocio ' || (MOD(g.n-1, 50) + 1)
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 7. Producto (500): producto n -> categoria n (mismo indice de rubro)
-- ---------------------------------------------------------------------
INSERT INTO Producto (id_categoria, nombre, descripcion, marca, estado)
SELECT g.n,
       REGEXP_SUBSTR('&v_item', '[^,]+', 1, MOD(g.n-1, 10) + 1) || ' modelo ' || g.n,
       'Producto de la categoria ' || REGEXP_SUBSTR('&v_cat', '[^,]+', 1, MOD(g.n-1, 10) + 1),
       REGEXP_SUBSTR('&v_marca', '[^,]+', 1, MOD(g.n-1, 10) + 1),
       CASE WHEN MOD(g.n, 40) = 0 THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 8. VarianteSKU (500): SKU n -> producto n. precio_venta = compra x 1.35
--    SKU 50, 100, 150... INACTIVOS
-- ---------------------------------------------------------------------
INSERT INTO VarianteSKU (id_producto, codigo_sku, talla, color, precio_venta, precio_compra, estado)
SELECT x.n,
       'SKU-' || LPAD(x.n, 5, '0'),
       REGEXP_SUBSTR('&v_talla', '[^,]+', 1, MOD(x.n-1, 5) + 1),
       REGEXP_SUBSTR('&v_color', '[^,]+', 1, MOD(x.n-1, 6) + 1),
       ROUND(x.pc * 1.35, 2),
       x.pc,
       CASE WHEN MOD(x.n, 50) = 0 THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM (SELECT g.n, ROUND(5 + MOD(g.n*37, 195) + MOD(g.n, 100)/100, 2) AS pc
      FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g) x
ORDER BY x.n;

-- ---------------------------------------------------------------------
-- 9. Compra (500)
--    proveedor = MOD(n-1,50)+1; sucursal = n (mismo negocio que el proveedor)
--    SKU = proveedor + 50 x MOD(TRUNC((n-1)/50),2)  (mismo negocio)
--    cantidad = MOD(n,20)+1; 1 de cada 30 ANULADA
-- ---------------------------------------------------------------------
INSERT INTO Compra (id_proveedor, id_sucursal, fecha_compra, numero_doc, subtotal, impuesto, total, estado)
SELECT x.prov, x.n, x.fecha,
       'F001-' || LPAD(x.n, 6, '0'),
       x.sub,
       ROUND(x.sub * 0.18, 2),
       x.sub + ROUND(x.sub * 0.18, 2),
       CASE WHEN MOD(x.n, 30) = 0 THEN 'ANULADA' ELSE 'REGISTRADA' END
FROM (SELECT g.n,
             MOD(g.n-1, 50) + 1                       AS prov,
             TRUNC(SYSDATE) - MOD(g.n*5, 120)         AS fecha,
             ROUND((MOD(g.n, 20) + 1) * s.precio_compra, 2) AS sub
      FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
      JOIN VarianteSKU s
        ON s.id_sku = MOD(g.n-1, 50) + 1 + 50 * MOD(TRUNC((g.n-1)/50), 2)) x
ORDER BY x.n;

-- ---------------------------------------------------------------------
-- 10. DetalleCompra (500): un item por compra
-- ---------------------------------------------------------------------
INSERT INTO DetalleCompra (id_compra, id_sku, cantidad, precio_unitario, subtotal)
SELECT c.id_compra,
       s.id_sku,
       MOD(c.id_compra, 20) + 1,
       s.precio_compra,
       c.subtotal
FROM Compra c
JOIN VarianteSKU s
  ON s.id_sku = MOD(c.id_compra-1, 50) + 1 + 50 * MOD(TRUNC((c.id_compra-1)/50), 2)
ORDER BY c.id_compra;

-- ---------------------------------------------------------------------
-- 11. Cliente (500): cliente n -> negocio MOD(n-1,50)+1
--     Cliente 1: documento 12345678 (lo usa el script de indices)
-- ---------------------------------------------------------------------
INSERT INTO Cliente (id_negocio, nombres, apellidos, documento, telefono, email)
SELECT MOD(g.n-1, 50) + 1,
       REGEXP_SUBSTR('&v_nom', '[^,]+', 1, MOD(g.n*7, 20) + 1),
       REGEXP_SUBSTR('&v_ape', '[^,]+', 1, MOD(g.n*9, 20) + 1),
       CASE WHEN g.n = 1 THEN '12345678' ELSE TO_CHAR(20000000 + g.n) END,
       '9' || TO_CHAR(30000000 + g.n*19),
       'cliente' || g.n || '@mypeinventario.pe'
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 12. Venta (500)
--     sucursal = MOD(n-1,20)+1 (empleado con el mismo id, misma sucursal)
--     cliente  = sucursal + 50 x MOD(n,10) (mismo negocio); cada 20 ventas
--                una sin cliente (mostrador)
--     SKU      = sucursal + 50 x MOD(TRUNC((n-1)/20),2)
--     cantidad = MOD(n,5)+1; descuento 5 % cada 10 ventas; IGV 18 %
--     1 de cada 25 ANULADA
-- ---------------------------------------------------------------------
INSERT INTO Venta (id_cliente, id_empleado, id_sucursal, fecha_venta, subtotal, descuento, impuesto, total, estado)
SELECT CASE WHEN MOD(y.n, 20) = 0 THEN NULL ELSE y.suc + 50 * MOD(y.n, 10) END,
       y.suc,
       y.suc,
       y.fecha,
       y.bruto,
       y.dsc,
       ROUND((y.bruto - y.dsc) * 0.18, 2),
       y.bruto - y.dsc + ROUND((y.bruto - y.dsc) * 0.18, 2),
       CASE WHEN MOD(y.n, 25) = 0 THEN 'ANULADA' ELSE 'REGISTRADA' END
FROM (SELECT x.n, x.suc, x.fecha, x.bruto,
             CASE WHEN MOD(x.n, 10) = 0 THEN ROUND(x.bruto * 0.05, 2) ELSE 0 END AS dsc
      FROM (SELECT g.n,
                   MOD(g.n-1, 20) + 1 AS suc,
                   TRUNC(SYSDATE) - 1 - MOD(g.n*7, 90) + (8 + MOD(g.n, 10))/24 AS fecha,
                   ROUND((MOD(g.n, 5) + 1) * s.precio_venta, 2) AS bruto
            FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
            JOIN VarianteSKU s
              ON s.id_sku = MOD(g.n-1, 20) + 1 + 50 * MOD(TRUNC((g.n-1)/20), 2)) x) y
ORDER BY y.n;

-- ---------------------------------------------------------------------
-- 13. DetalleVenta (500): un item por venta (subtotal = bruto - descuento)
-- ---------------------------------------------------------------------
INSERT INTO DetalleVenta (id_venta, id_sku, cantidad, precio_unitario, descuento, subtotal)
SELECT v.id_venta,
       s.id_sku,
       MOD(v.id_venta, 5) + 1,
       s.precio_venta,
       v.descuento,
       v.subtotal - v.descuento
FROM Venta v
JOIN VarianteSKU s
  ON s.id_sku = MOD(v.id_venta-1, 20) + 1 + 50 * MOD(TRUNC((v.id_venta-1)/20), 2)
ORDER BY v.id_venta;

-- ---------------------------------------------------------------------
-- 14. MetodoPago (500): un pago por venta, por el total de la venta
-- ---------------------------------------------------------------------
INSERT INTO MetodoPago (id_venta, tipo_pago, monto, referencia)
SELECT v.id_venta,
       REGEXP_SUBSTR('&v_pago', '[^,]+', 1, MOD(v.id_venta-1, 6) + 1),
       v.total,
       CASE WHEN MOD(v.id_venta-1, 6) = 0 THEN NULL
            ELSE 'OP-' || LPAD(v.id_venta, 7, '0') END
FROM Venta v
ORDER BY v.id_venta;

-- ---------------------------------------------------------------------
-- 15. DireccionCliente (500): una direccion principal por cliente
-- ---------------------------------------------------------------------
INSERT INTO DireccionCliente (id_cliente, direccion, referencia, distrito, provincia, departamento, codigo_postal, principal)
SELECT g.n,
       REGEXP_SUBSTR('&v_calle', '[^,]+', 1, MOD(g.n*3, 10) + 1) || ' ' || (400 + g.n),
       'Cerca al paradero ' || MOD(g.n, 40),
       REGEXP_SUBSTR('&v_dist', '[^,]+', 1, MOD(g.n-1, 10) + 1),
       'Lima',
       'Lima',
       'LIMA' || LPAD(MOD(g.n, 40) + 1, 2, '0'),
       1
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 16. Pedido (500)
--     cliente = n; sucursal = MOD(n-1,50)+1 (mismo negocio que el cliente);
--     cada 10 pedidos uno sin sucursal (pedido en linea)
--     SKU = sucursal + 50 x MOD(TRUNC((n-1)/50),2); cantidad = MOD(n,4)+1
--     descuento 10 % cada 8 pedidos; IGV 18 %; estados rotativos
-- ---------------------------------------------------------------------
INSERT INTO Pedido (id_cliente, id_sucursal, fecha_pedido, estado, subtotal, descuento, impuesto, total)
SELECT y.n,
       CASE WHEN MOD(y.n, 10) = 0 THEN NULL ELSE y.suc END,
       y.fecha,
       REGEXP_SUBSTR('&v_estped', '[^,]+', 1, MOD(y.n-1, 4) + 1),
       y.bruto,
       y.dsc,
       ROUND((y.bruto - y.dsc) * 0.18, 2),
       y.bruto - y.dsc + ROUND((y.bruto - y.dsc) * 0.18, 2)
FROM (SELECT x.n, x.suc, x.fecha, x.bruto,
             CASE WHEN MOD(x.n, 8) = 0 THEN ROUND(x.bruto * 0.10, 2) ELSE 0 END AS dsc
      FROM (SELECT g.n,
                   MOD(g.n-1, 50) + 1 AS suc,
                   TRUNC(SYSDATE) - 1 - MOD(g.n*3, 60) AS fecha,
                   ROUND((MOD(g.n, 4) + 1) * s.precio_venta, 2) AS bruto
            FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
            JOIN VarianteSKU s
              ON s.id_sku = MOD(g.n-1, 50) + 1 + 50 * MOD(TRUNC((g.n-1)/50), 2)) x) y
ORDER BY y.n;

-- ---------------------------------------------------------------------
-- 17. DetallePedido (500): un item por pedido
-- ---------------------------------------------------------------------
INSERT INTO DetallePedido (id_pedido, id_sku, cantidad, precio_unitario, descuento, subtotal)
SELECT p.id_pedido,
       s.id_sku,
       MOD(p.id_pedido, 4) + 1,
       s.precio_venta,
       p.descuento,
       p.subtotal - p.descuento
FROM Pedido p
JOIN VarianteSKU s
  ON s.id_sku = MOD(p.id_pedido-1, 50) + 1 + 50 * MOD(TRUNC((p.id_pedido-1)/50), 2)
ORDER BY p.id_pedido;

-- ---------------------------------------------------------------------
-- 18. CanalVenta (500): canal n -> negocio MOD(n-1,50)+1
--     Los nombres se repiten entre negocios (8 tipos de canal), por eso
--     sp_reporte_ventas_canal agrupa por nombre.
-- ---------------------------------------------------------------------
INSERT INTO CanalVenta (id_negocio, nombre, descripcion, estado)
SELECT MOD(g.n-1, 50) + 1,
       REGEXP_SUBSTR('&v_canal', '[^,]+', 1, MOD(g.n-1, 8) + 1),
       'Canal ' || REGEXP_SUBSTR('&v_canal', '[^,]+', 1, MOD(g.n-1, 8) + 1) ||
         ' del negocio ' || (MOD(g.n-1, 50) + 1),
       CASE WHEN MOD(g.n, 25) = 0 THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g
ORDER BY g.n;

-- ---------------------------------------------------------------------
-- 19. VentaCanal (500): exactamente un canal por venta, del mismo negocio
--     canal = sucursal + 50 x MOD(TRUNC((venta-1)/20),10)
-- ---------------------------------------------------------------------
INSERT INTO VentaCanal (id_venta, id_canal, referencia_externa, fecha_registro)
SELECT v.id_venta,
       v.id_sucursal + 50 * MOD(TRUNC((v.id_venta-1)/20), 10),
       CASE WHEN MOD(v.id_sucursal + 50 * MOD(TRUNC((v.id_venta-1)/20), 10) - 1, 8) = 0
            THEN NULL
            ELSE 'EXT-' || LPAD(v.id_venta, 6, '0') END,
       v.fecha_venta
FROM Venta v
ORDER BY v.id_venta;

-- ---------------------------------------------------------------------
-- 20. PromocionComercial (500): promocion n -> negocio MOD(n-1,50)+1
--     VENCIDA si ya termino; si no, INACTIVA cada 17 y el resto ACTIVA
-- ---------------------------------------------------------------------
INSERT INTO PromocionComercial (id_negocio, nombre, descripcion, tipo, valor, fecha_inicio, fecha_fin, estado)
SELECT MOD(x.n-1, 50) + 1,
       'Promocion ' || LPAD(x.n, 3, '0'),
       'Promocion comercial ' || x.tipo || ' del negocio ' || (MOD(x.n-1, 50) + 1),
       x.tipo,
       ROUND(5 + MOD(x.n*3, 40), 2),
       x.inicio,
       x.inicio + 20 + MOD(x.n*7, 70),
       CASE WHEN x.inicio + 20 + MOD(x.n*7, 70) < TRUNC(SYSDATE) THEN 'VENCIDA'
            WHEN MOD(x.n, 17) = 0 THEN 'INACTIVA'
            ELSE 'ACTIVA' END
FROM (SELECT g.n,
             REGEXP_SUBSTR('&v_tipopr', '[^,]+', 1, MOD(g.n-1, 4) + 1) AS tipo,
             TRUNC(SYSDATE) - MOD(g.n*13, 150) - 5 AS inicio
      FROM (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 500) g) x
ORDER BY x.n;

COMMIT;


-- ---------------------------------------------------------------------
-- VERIFICACION 1: 500 registros por tabla (20 filas, todas con 500)
-- ---------------------------------------------------------------------
COLUMN tabla FORMAT A22
SELECT 'Comerciante' AS tabla, COUNT(*) AS registros FROM Comerciante
UNION ALL SELECT 'Negocio',            COUNT(*) FROM Negocio
UNION ALL SELECT 'Sucursal',           COUNT(*) FROM Sucursal
UNION ALL SELECT 'Empleado',           COUNT(*) FROM Empleado
UNION ALL SELECT 'Proveedor',          COUNT(*) FROM Proveedor
UNION ALL SELECT 'CategoriaProducto',  COUNT(*) FROM CategoriaProducto
UNION ALL SELECT 'Producto',           COUNT(*) FROM Producto
UNION ALL SELECT 'VarianteSKU',        COUNT(*) FROM VarianteSKU
UNION ALL SELECT 'Compra',             COUNT(*) FROM Compra
UNION ALL SELECT 'DetalleCompra',      COUNT(*) FROM DetalleCompra
UNION ALL SELECT 'Cliente',            COUNT(*) FROM Cliente
UNION ALL SELECT 'Venta',              COUNT(*) FROM Venta
UNION ALL SELECT 'DetalleVenta',       COUNT(*) FROM DetalleVenta
UNION ALL SELECT 'MetodoPago',         COUNT(*) FROM MetodoPago
UNION ALL SELECT 'DireccionCliente',   COUNT(*) FROM DireccionCliente
UNION ALL SELECT 'Pedido',             COUNT(*) FROM Pedido
UNION ALL SELECT 'DetallePedido',      COUNT(*) FROM DetallePedido
UNION ALL SELECT 'CanalVenta',         COUNT(*) FROM CanalVenta
UNION ALL SELECT 'VentaCanal',         COUNT(*) FROM VentaCanal
UNION ALL SELECT 'PromocionComercial', COUNT(*) FROM PromocionComercial;

-- ---------------------------------------------------------------------
-- VERIFICACION 2: coherencia de totales (todas las cifras deben ser 0)
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM Venta  WHERE total <> subtotal - descuento + impuesto)  AS venta_descuadrada,
  (SELECT COUNT(*) FROM Compra WHERE total <> subtotal + impuesto)              AS compra_descuadrada,
  (SELECT COUNT(*) FROM Pedido WHERE total <> subtotal - descuento + impuesto)  AS pedido_descuadrado,
  (SELECT COUNT(*) FROM Venta v
     JOIN DetalleVenta d ON d.id_venta = v.id_venta
    WHERE v.subtotal <> ROUND(d.cantidad * d.precio_unitario, 2)
       OR v.descuento <> d.descuento)                                           AS venta_vs_detalle,
  (SELECT COUNT(*) FROM Venta v
     JOIN MetodoPago m ON m.id_venta = v.id_venta
    WHERE m.monto <> v.total)                                                   AS pago_vs_venta
FROM dual;

-- ---------------------------------------------------------------------
-- VERIFICACION 3: casos de prueba para los otros scripts
-- ---------------------------------------------------------------------
SELECT id_cliente, id_negocio, documento FROM Cliente WHERE documento = '12345678';
SELECT id_venta, estado FROM Venta WHERE id_venta IN (1, 25);
SELECT id_sku, estado FROM VarianteSKU WHERE id_sku IN (1, 2, 50);

-- Una vez creado el script 4, probar:
--   SELECT fn_total_ventas_sucursal(1, TRUNC(SYSDATE) - 90, TRUNC(SYSDATE)) AS total FROM dual;
