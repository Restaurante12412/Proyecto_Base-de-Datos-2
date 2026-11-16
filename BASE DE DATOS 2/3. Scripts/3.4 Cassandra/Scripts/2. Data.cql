-- ============================================================
-- 2. Data.cql  -  Carga de datos en mype_cassandra
-- Se ejecuta DESDE cqlsh, con los CSV ya copiados a /tmp del nodo.
-- Los CSV se copian con "2a. Cargar_Data.sh" (que tambien lanza este archivo).
--
-- Origen de los datos:
--   Tablas 4 y 5 -> exportadas de Oracle (ver "2b. Exportar_Oracle.sql")
--   Tablas 1 a 3 -> exportadas de PostgreSQL (ver "2c. Exportar_PostgreSQL.sql");
--                   los 3 CSV ya estan en la carpeta "csv"
-- ============================================================

-- Tabla 4: ventas_por_sucursal_dia (Oracle, 100 filas)
COPY mype_cassandra.ventas_por_sucursal_dia
  (id_sucursal, fecha_dia, fecha_venta, id_venta, id_cliente, id_empleado, canal, estado, num_items, subtotal, descuento, impuesto, total)
FROM '/tmp/ventas_sucursal_dia.csv' WITH HEADER = TRUE;

-- Tabla 5: ventas_por_cliente (Oracle, 100 filas)
COPY mype_cassandra.ventas_por_cliente
  (id_cliente, fecha_venta, id_venta, id_sucursal, canal, estado, num_items, total)
FROM '/tmp/ventas_cliente.csv' WITH HEADER = TRUE;

-- Tabla 1: movimientos_por_sku (PostgreSQL, 500 filas)
COPY mype_cassandra.movimientos_por_sku
  (id_sucursal, id_sku, anio_mes, fecha_movimiento, id_movimiento, id_stock, id_tipo_movimiento, tipo_movimiento, afecta_stock, cantidad, observacion)
FROM '/tmp/movimientos_sku.csv' WITH HEADER = TRUE;

-- Tabla 2: historial_stock_por_sku (PostgreSQL, 500 filas)
COPY mype_cassandra.historial_stock_por_sku
  (id_sku, id_almacen, anio, fecha_cambio, id_historial, id_stock, cantidad_anterior, cantidad_nueva, motivo)
FROM '/tmp/historial_stock.csv' WITH HEADER = TRUE;

-- Tabla 3: alertas_por_sucursal (PostgreSQL, 500 filas)
COPY mype_cassandra.alertas_por_sucursal
  (id_sucursal, estado, fecha_alerta, id_alerta, id_stock, id_sku, id_configuracion, cantidad_detectada, stock_minimo, cantidad_reabastecimiento, fecha_resolucion)
FROM '/tmp/alertas_sucursal.csv' WITH HEADER = TRUE;

-- Verificacion (esperado: 500 / 500 / 500 / 100 / 100)
SELECT COUNT(*) FROM mype_cassandra.movimientos_por_sku;
SELECT COUNT(*) FROM mype_cassandra.historial_stock_por_sku;
SELECT COUNT(*) FROM mype_cassandra.alertas_por_sucursal;
SELECT COUNT(*) FROM mype_cassandra.ventas_por_sucursal_dia;
SELECT COUNT(*) FROM mype_cassandra.ventas_por_cliente;
