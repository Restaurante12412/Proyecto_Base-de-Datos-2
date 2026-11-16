-- ============================================================
-- 3. Replicacion.cql  -  Prueba de replicacion asincronica
-- Ejecutar con el nodo mype-cass3 CAIDO (ver "3b. Replicacion.sh", que
-- ordena todos los pasos). Aqui solo van las sentencias CQL.
-- ============================================================

-- PASO A (nodo mype-cass3 apagado, cqlsh en mype-cass1):
-- el cliente recibe confirmacion con 2 de 3 replicas (quorum).
CONSISTENCY LOCAL_QUORUM;
INSERT INTO mype_cassandra.ventas_por_sucursal_dia
  (id_sucursal, fecha_dia, fecha_venta, id_venta, id_empleado, canal, estado)
VALUES (1, '2026-11-15', '2026-11-15 10:00:00', 900001, 37, 'PRUEBA_REPLICACION', 'COMPLETADA');

-- Lectura en mype-cass1 (la fila existe)
SELECT id_venta, canal, estado FROM mype_cassandra.ventas_por_sucursal_dia
WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15';

-- PASO B (despues de levantar mype-cass3, cqlsh DENTRO de mype-cass3):
-- la fila aparece sin repair (hinted handoff).
CONSISTENCY ONE;
SELECT id_venta, canal, estado FROM mype_cassandra.ventas_por_sucursal_dia
WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15';

-- PASO C: borrar la fila de prueba
CONSISTENCY LOCAL_QUORUM;
DELETE FROM mype_cassandra.ventas_por_sucursal_dia
WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15'
  AND fecha_venta = '2026-11-15 10:00:00' AND id_venta = 900001;

-- Evidencia del borrado (debe dar 0 rows)
SELECT id_venta FROM mype_cassandra.ventas_por_sucursal_dia
WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15';
