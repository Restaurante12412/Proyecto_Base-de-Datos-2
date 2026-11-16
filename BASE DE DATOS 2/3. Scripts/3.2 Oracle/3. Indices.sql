-- =====================================================================
-- MypeInventario - ORACLE
-- 3. Indices
-- Ejecutar conectado como MYPE_INVENTARIO, con los datos ya cargados
-- ("6. Data.sql"), para que la comparacion de planes tenga sentido:
--   sqlplus MYPE_INVENTARIO@localhost:1521/FREEPDB1 @"3. Indices.sql"
--
-- Por cada indice: la consulta frecuente que lo justifica, el plan de
-- ejecucion ANTES de crearlo, la creacion y el plan DESPUES.
-- Oracle crea indice automatico para las claves primarias y las
-- restricciones UNIQUE, pero NO para las claves foraneas; estos indices
-- cubren columnas de busqueda y de union que no lo tenian.
--
--   1. idx_venta_sucursal_fecha     Venta (id_sucursal, fecha_venta)
--   2. idx_detventa_venta           DetalleVenta (id_venta)
--   3. idx_detventa_sku             DetalleVenta (id_sku)
--   4. idx_compra_proveedor_fecha   Compra (id_proveedor, fecha_compra)
--   5. idx_cliente_negocio_doc      Cliente (id_negocio, documento)
-- =====================================================================
SET LINESIZE 150
SET PAGESIZE 100

-- Estadisticas actualizadas antes de comparar
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(USER);
END;
/


-- ---------------------------------------------------------------------
-- 1. idx_venta_sucursal_fecha
--    Integrante responsable: (completar)
--    Consulta frecuente: ventas de una sucursal en los ultimos 30 dias
--    (cierre de caja y reportes; la usa fn_total_ventas_sucursal).
--    Justificacion: Venta es la tabla que mas crece; la clave foranea
--    id_sucursal no tiene indice y la consulta siempre agrega la fecha.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN PLAN FOR
SELECT id_venta, fecha_venta, total
FROM Venta
WHERE id_sucursal = 1
  AND fecha_venta >= TRUNC(SYSDATE) - 30;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

CREATE INDEX idx_venta_sucursal_fecha
    ON Venta (id_sucursal, fecha_venta);

-- DESPUES
EXPLAIN PLAN FOR
SELECT id_venta, fecha_venta, total
FROM Venta
WHERE id_sucursal = 1
  AND fecha_venta >= TRUNC(SYSDATE) - 30;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- ---------------------------------------------------------------------
-- 2. idx_detventa_venta
--    Integrante responsable: (completar)
--    Consulta frecuente: detalle de una venta (ver o imprimir el
--    comprobante; recalculo de totales en sp_registrar_detalle_venta).
--    Justificacion: la clave foranea id_venta no tiene indice; sin el,
--    cada consulta del detalle recorre toda la tabla DetalleVenta.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN PLAN FOR
SELECT id_detalle_venta, id_sku, cantidad, precio_unitario, subtotal
FROM DetalleVenta
WHERE id_venta = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

CREATE INDEX idx_detventa_venta
    ON DetalleVenta (id_venta);

-- DESPUES
EXPLAIN PLAN FOR
SELECT id_detalle_venta, id_sku, cantidad, precio_unitario, subtotal
FROM DetalleVenta
WHERE id_venta = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- ---------------------------------------------------------------------
-- 3. idx_detventa_sku
--    Integrante responsable: (completar)
--    Consulta frecuente: unidades e importe vendidos de un SKU (productos
--    mas vendidos, rotacion).
--    Justificacion: la clave foranea id_sku no tiene indice y es el
--    filtro de todos los reportes por producto.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN PLAN FOR
SELECT SUM(cantidad) AS unidades, SUM(subtotal) AS importe
FROM DetalleVenta
WHERE id_sku = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

CREATE INDEX idx_detventa_sku
    ON DetalleVenta (id_sku);

-- DESPUES
EXPLAIN PLAN FOR
SELECT SUM(cantidad) AS unidades, SUM(subtotal) AS importe
FROM DetalleVenta
WHERE id_sku = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- ---------------------------------------------------------------------
-- 4. idx_compra_proveedor_fecha
--    Integrante responsable: (completar)
--    Consulta frecuente: compras a un proveedor en los ultimos 3 meses
--    (historial del proveedor; la usa sp_reporte_compras_proveedor).
--    Justificacion: la clave foranea id_proveedor no tiene indice y la
--    consulta siempre se acota por fecha.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN PLAN FOR
SELECT id_compra, fecha_compra, numero_doc, total
FROM Compra
WHERE id_proveedor = 1
  AND fecha_compra >= ADD_MONTHS(TRUNC(SYSDATE), -3);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

CREATE INDEX idx_compra_proveedor_fecha
    ON Compra (id_proveedor, fecha_compra);

-- DESPUES
EXPLAIN PLAN FOR
SELECT id_compra, fecha_compra, numero_doc, total
FROM Compra
WHERE id_proveedor = 1
  AND fecha_compra >= ADD_MONTHS(TRUNC(SYSDATE), -3);
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- ---------------------------------------------------------------------
-- 5. idx_cliente_negocio_doc
--    Integrante responsable: (completar)
--    Consulta frecuente: buscar un cliente por su documento al registrar
--    una venta o un pedido.
--    Justificacion: Cliente.documento no tiene restriccion UNIQUE ni
--    indice; la busqueda se hace siempre dentro de un negocio.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN PLAN FOR
SELECT id_cliente, nombres, apellidos, telefono
FROM Cliente
WHERE id_negocio = 1
  AND documento = '12345678';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

CREATE INDEX idx_cliente_negocio_doc
    ON Cliente (id_negocio, documento);

-- DESPUES
EXPLAIN PLAN FOR
SELECT id_cliente, nombres, apellidos, telefono
FROM Cliente
WHERE id_negocio = 1
  AND documento = '12345678';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- ---------------------------------------------------------------------
-- VERIFICACION: indices creados
-- ---------------------------------------------------------------------
COLUMN table_name FORMAT A20
COLUMN index_name FORMAT A28
COLUMN columnas FORMAT A30

SELECT table_name, index_name,
       LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_position) AS columnas
FROM user_ind_columns
WHERE index_name LIKE 'IDX\_%' ESCAPE '\'
GROUP BY table_name, index_name
ORDER BY table_name, index_name;
