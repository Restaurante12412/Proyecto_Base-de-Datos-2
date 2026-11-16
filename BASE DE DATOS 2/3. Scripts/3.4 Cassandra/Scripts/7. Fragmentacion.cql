-- ============================================================
-- 7. Fragmentacion.cql  -  Evidencia del esquema de fragmentacion
-- En Cassandra la fragmentacion es la partition key: cada valor de la
-- partition key se hashea (Murmur3) a un token y cae en un rango del anillo.
-- Con RF 3 y 3 nodos, los 3 nodos guardan cada particion.
-- ============================================================

-- Partition key de cada tabla (clustering = orden dentro de la particion)
SELECT table_name, column_name, kind, position
FROM system_schema.columns
WHERE keyspace_name = 'mype_cassandra'
  AND kind IN ('partition_key','clustering');

-- Token (posicion en el anillo) de algunas particiones
SELECT id_sucursal, fecha_dia, token(id_sucursal, fecha_dia) AS token
FROM mype_cassandra.ventas_por_sucursal_dia
WHERE id_sucursal = 1 AND fecha_dia = '2026-08-27';

SELECT DISTINCT id_cliente, token(id_cliente) AS token
FROM mype_cassandra.ventas_por_cliente LIMIT 5;

SELECT DISTINCT id_sucursal, estado, token(id_sucursal, estado) AS token
FROM mype_cassandra.alertas_por_sucursal LIMIT 5;

-- Replicas de una particion (ejecutar en la terminal, no en cqlsh; CASS_PW es la
-- clave del superusuario:  read -s -p "Clave cassandra: " CASS_PW):
--   docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" getendpoints mype_cassandra ventas_por_cliente 1
--   docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" getendpoints mype_cassandra ventas_por_sucursal_dia 1:2026-08-27
--   docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" ring mype_cassandra
--   docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" status mype_cassandra
