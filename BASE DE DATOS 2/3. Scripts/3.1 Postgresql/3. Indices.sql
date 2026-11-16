-- =====================================================================
-- MypeInventario - PostgreSQL
-- 3. Indices
-- Ejecutar conectado a la base "MypeInventario", con los datos ya cargados
-- ("6. Data.sql"), para que la comparacion de rendimiento tenga sentido:
--   psql -U postgres -d "MypeInventario" -f "3. Indices.sql"
--
-- Por cada indice: la consulta frecuente que lo justifica, el plan ANTES
-- de crearlo (EXPLAIN ANALYZE), la creacion y el plan DESPUES.
-- Las claves primarias y las restricciones UNIQUE ya tienen indice propio;
-- estos indices cubren columnas de busqueda que no lo tenian.
--
--   1. idx_movimiento_stock_fecha   MovimientoInventario (id_stock, fecha_movimiento)
--   2. idx_stock_sku                Stock (id_sku)
--   3. idx_alerta_pendiente         AlertaReabastecimiento (id_stock) WHERE estado = 'PENDIENTE'
--   4. idx_movimiento_fecha         MovimientoInventario (fecha_movimiento)
--   5. idx_lote_vencimiento         LoteProducto (fecha_vencimiento) WHERE estado = 'ACTIVO'
-- =====================================================================

-- Estadisticas actualizadas antes de comparar
ANALYZE;


-- ---------------------------------------------------------------------
-- 1. idx_movimiento_stock_fecha
--    Integrante responsable: (completar)
--    Consulta frecuente: kardex de un producto en una ubicacion (ultimos
--    movimientos de un registro de Stock, del mas reciente al mas antiguo).
--    Justificacion: MovimientoInventario es la tabla que mas crece y solo
--    tiene indice en su clave primaria; sin este indice cada consulta de
--    kardex recorre toda la tabla y luego ordena.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN ANALYZE
SELECT id_movimiento, id_tipo_movimiento, cantidad, fecha_movimiento
FROM MovimientoInventario
WHERE id_stock = 1
ORDER BY fecha_movimiento DESC
LIMIT 20;

CREATE INDEX idx_movimiento_stock_fecha
    ON MovimientoInventario (id_stock, fecha_movimiento DESC);

-- DESPUES
EXPLAIN ANALYZE
SELECT id_movimiento, id_tipo_movimiento, cantidad, fecha_movimiento
FROM MovimientoInventario
WHERE id_stock = 1
ORDER BY fecha_movimiento DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- 2. idx_stock_sku
--    Integrante responsable: (completar)
--    Consulta frecuente: existencias de un SKU en todas las ubicaciones
--    (la usa fn_consultar_existencias y la consulta de disponibilidad
--    antes de vender).
--    Justificacion: la restriccion UNIQUE (id_ubicacion, id_sku) empieza
--    por id_ubicacion, asi que no sirve para buscar solo por id_sku.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN ANALYZE
SELECT id_stock, id_ubicacion, cantidad_actual, cantidad_disponible
FROM Stock
WHERE id_sku = 1;

CREATE INDEX idx_stock_sku
    ON Stock (id_sku);

-- DESPUES
EXPLAIN ANALYZE
SELECT id_stock, id_ubicacion, cantidad_actual, cantidad_disponible
FROM Stock
WHERE id_sku = 1;


-- ---------------------------------------------------------------------
-- 3. idx_alerta_pendiente
--    Integrante responsable: (completar)
--    Consulta frecuente: alertas de reabastecimiento pendientes (pantalla
--    de alertas y verificacion que hace sp_controlar_stock_minimo).
--    Justificacion: indice parcial; solo guarda las alertas PENDIENTE, que
--    son una fraccion pequena de la tabla, por lo que ocupa poco y no
--    crece con el historial de alertas resueltas.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN ANALYZE
SELECT id_alerta, id_stock, id_configuracion, cantidad_detectada, fecha_alerta
FROM AlertaReabastecimiento
WHERE estado = 'PENDIENTE';

CREATE INDEX idx_alerta_pendiente
    ON AlertaReabastecimiento (id_stock)
    WHERE estado = 'PENDIENTE';

-- DESPUES
EXPLAIN ANALYZE
SELECT id_alerta, id_stock, id_configuracion, cantidad_detectada, fecha_alerta
FROM AlertaReabastecimiento
WHERE estado = 'PENDIENTE';


-- ---------------------------------------------------------------------
-- 4. idx_movimiento_fecha
--    Integrante responsable: (completar)
--    Consulta frecuente: movimientos de un periodo (reporte diario o
--    semanal; la usa fn_reporte_movimientos).
--    Justificacion: los reportes filtran por rango de fechas sin indicar
--    el stock, por lo que el indice 1 (que empieza por id_stock) no aplica.
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN ANALYZE
SELECT count(*), sum(cantidad)
FROM MovimientoInventario
WHERE fecha_movimiento >= '2026-10-01'
  AND fecha_movimiento <  '2026-11-01';

CREATE INDEX idx_movimiento_fecha
    ON MovimientoInventario (fecha_movimiento);

-- DESPUES
EXPLAIN ANALYZE
SELECT count(*), sum(cantidad)
FROM MovimientoInventario
WHERE fecha_movimiento >= '2026-10-01'
  AND fecha_movimiento <  '2026-11-01';


-- ---------------------------------------------------------------------
-- 5. idx_lote_vencimiento
--    Integrante responsable: (completar)
--    Consulta frecuente: lotes activos que vencen en los proximos 30 dias.
--    Justificacion: indice parcial sobre los lotes ACTIVO; la busqueda por
--    fecha de vencimiento no tenia ningun indice (el UNIQUE existente es
--    por id_sku y numero_lote).
-- ---------------------------------------------------------------------
-- ANTES
EXPLAIN ANALYZE
SELECT id_lote, id_sku, numero_lote, fecha_vencimiento
FROM LoteProducto
WHERE estado = 'ACTIVO'
  AND fecha_vencimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
ORDER BY fecha_vencimiento;

CREATE INDEX idx_lote_vencimiento
    ON LoteProducto (fecha_vencimiento)
    WHERE estado = 'ACTIVO';

-- DESPUES
EXPLAIN ANALYZE
SELECT id_lote, id_sku, numero_lote, fecha_vencimiento
FROM LoteProducto
WHERE estado = 'ACTIVO'
  AND fecha_vencimiento BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
ORDER BY fecha_vencimiento;


-- ---------------------------------------------------------------------
-- VERIFICACION: indices creados
-- ---------------------------------------------------------------------
SELECT tablename AS tabla, indexname AS indice, indexdef AS definicion
FROM pg_indexes
WHERE schemaname = 'public' AND indexname LIKE 'idx\_%'
ORDER BY tablename, indexname;
