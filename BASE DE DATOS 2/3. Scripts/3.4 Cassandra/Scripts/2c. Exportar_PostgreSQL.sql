-- ============================================================
-- 2c. Exportar_PostgreSQL.sql
-- Genera los 3 CSV de Cassandra que salen de PostgreSQL (tablas 1 a 3).
-- Los otros 2 CSV (ventas) salen de Oracle con "2b. Exportar_Oracle.sql".
--
-- Ejecutar con psql conectado a "MypeInventario" (usa \copy, que es un
-- comando de psql; no funciona en el Query Tool de pgAdmin):
--   docker cp "2c. Exportar_PostgreSQL.sql" mype-postgres:/tmp/2c.sql
--   docker exec mype-postgres psql -U postgres -d "MypeInventario" -f /tmp/2c.sql
--   docker cp mype-postgres:/tmp/movimientos_sku.csv  csv/
--   docker cp mype-postgres:/tmp/historial_stock.csv  csv/
--   docker cp mype-postgres:/tmp/alertas_sucursal.csv csv/
-- Los 3 CSV ya generados estan en la carpeta "csv" junto a este script.
--
-- La sucursal de cada registro se obtiene por el camino
--   Stock -> UbicacionProducto -> Almacen -> Inventario (id_sucursal).
-- Resultado esperado: 500 filas en cada archivo.
-- ============================================================

-- Archivo: movimientos_sku.csv  (tabla 1: movimientos_por_sku)
\copy (SELECT i.id_sucursal, s.id_sku, to_char(m.fecha_movimiento, 'YYYYMM')::int AS anio_mes, to_char(m.fecha_movimiento, 'YYYY-MM-DD HH24:MI:SS') AS fecha_movimiento, m.id_movimiento, m.id_stock, m.id_tipo_movimiento, t.nombre AS tipo_movimiento, CASE WHEN t.afecta_stock THEN 'True' ELSE 'False' END AS afecta_stock, m.cantidad, m.observacion FROM MovimientoInventario m JOIN TipoMovimiento t ON t.id_tipo_movimiento = m.id_tipo_movimiento JOIN Stock s ON s.id_stock = m.id_stock JOIN UbicacionProducto u ON u.id_ubicacion = s.id_ubicacion JOIN Almacen a ON a.id_almacen = u.id_almacen JOIN Inventario i ON i.id_inventario = a.id_inventario ORDER BY i.id_sucursal, s.id_sku, m.fecha_movimiento, m.id_movimiento) TO '/tmp/movimientos_sku.csv' WITH (FORMAT csv, HEADER true)

-- Archivo: historial_stock.csv  (tabla 2: historial_stock_por_sku)
\copy (SELECT s.id_sku, u.id_almacen, extract(year FROM h.fecha_cambio)::int AS anio, to_char(h.fecha_cambio, 'YYYY-MM-DD HH24:MI:SS') AS fecha_cambio, h.id_historial, h.id_stock, h.cantidad_anterior, h.cantidad_nueva, h.motivo FROM HistorialStock h JOIN Stock s ON s.id_stock = h.id_stock JOIN UbicacionProducto u ON u.id_ubicacion = s.id_ubicacion ORDER BY s.id_sku, u.id_almacen, h.fecha_cambio, h.id_historial) TO '/tmp/historial_stock.csv' WITH (FORMAT csv, HEADER true)

-- Archivo: alertas_sucursal.csv  (tabla 3: alertas_por_sucursal)
\copy (SELECT i.id_sucursal, al.estado, to_char(al.fecha_alerta, 'YYYY-MM-DD HH24:MI:SS') AS fecha_alerta, al.id_alerta, al.id_stock, s.id_sku, al.id_configuracion, al.cantidad_detectada, c.stock_minimo, c.cantidad_reabastecimiento, to_char(al.fecha_resolucion, 'YYYY-MM-DD HH24:MI:SS') AS fecha_resolucion FROM AlertaReabastecimiento al JOIN ConfiguracionReabastecimiento c ON c.id_configuracion = al.id_configuracion JOIN Stock s ON s.id_stock = al.id_stock JOIN UbicacionProducto u ON u.id_ubicacion = s.id_ubicacion JOIN Almacen a ON a.id_almacen = u.id_almacen JOIN Inventario i ON i.id_inventario = a.id_inventario ORDER BY i.id_sucursal, al.estado, al.fecha_alerta, al.id_alerta) TO '/tmp/alertas_sucursal.csv' WITH (FORMAT csv, HEADER true)

-- Verificacion (deben ser 500 / 500 / 500)
SELECT (SELECT count(*) FROM MovimientoInventario)   AS movimientos,
       (SELECT count(*) FROM HistorialStock)         AS historial,
       (SELECT count(*) FROM AlertaReabastecimiento) AS alertas;
