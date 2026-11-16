-- ============================================================
-- 4. Consultas.cql  -  Consultas de negocio (keyspace mype_cassandra)
--    Integrante responsable: (completar)
-- Todas usan la partition key completa (sin ALLOW FILTERING).
-- ============================================================

-- 1. Ventas de una sucursal en un dia (tabla 4)
--    Integrante responsable: (completar)
--    Esperado: 3 ventas (ids 101, 281, 461), total_dia = 1010.06
SELECT id_venta, fecha_venta, canal, estado, num_items, total
FROM mype_cassandra.ventas_por_sucursal_dia
WHERE id_sucursal = 1 AND fecha_dia = '2026-08-27';

SELECT COUNT(*) AS ventas, SUM(total) AS total_dia
FROM mype_cassandra.ventas_por_sucursal_dia
WHERE id_sucursal = 1 AND fecha_dia = '2026-08-27';

-- 2. Historial de compras de un cliente (tabla 5)
--    Integrante responsable: (completar)
--    Clientes con ventas cargadas (para elegir otro id si se desea):
SELECT DISTINCT id_cliente FROM mype_cassandra.ventas_por_cliente LIMIT 5;
--    Historial del cliente 51 (compra en la sucursal 1):
SELECT fecha_venta, id_venta, id_sucursal, canal, estado, total
FROM mype_cassandra.ventas_por_cliente
WHERE id_cliente = 51;

-- 3. Entradas y salidas de un SKU en una sucursal en un mes (tabla 1)
--    Integrante responsable: (completar)
--    Esperado: 6 filas
SELECT fecha_movimiento, tipo_movimiento, cantidad, observacion
FROM mype_cassandra.movimientos_por_sku
WHERE id_sucursal = 3 AND id_sku = 226 AND anio_mes = 202609;

--    Variante con rango por clustering key
SELECT fecha_movimiento, tipo_movimiento, cantidad
FROM mype_cassandra.movimientos_por_sku
WHERE id_sucursal = 3 AND id_sku = 226 AND anio_mes = 202609
  AND fecha_movimiento >= '2026-09-15';

-- 4. Evolucion del stock de un SKU en un almacen (tabla 2)
--    Esperado: 10 filas; cada cantidad_anterior = cantidad_nueva del cambio previo
SELECT fecha_cambio, cantidad_anterior, cantidad_nueva, motivo
FROM mype_cassandra.historial_stock_por_sku
WHERE id_sku = 457 AND id_almacen = 343 AND anio = 2026;

-- 5. Alertas de reabastecimiento pendientes de una sucursal (tabla 3)
--    Integrante responsable: (completar)
--    Esperado: 12 filas con cantidad_detectada < stock_minimo
SELECT fecha_alerta, id_sku, cantidad_detectada, stock_minimo, cantidad_reabastecimiento
FROM mype_cassandra.alertas_por_sucursal
WHERE id_sucursal = 1 AND estado = 'PENDIENTE';
