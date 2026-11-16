-- ============================================================
-- 5. Usuarios.cql  -  Roles y permisos (mismos nombres que Oracle)
-- Ejecutar como superusuario:
--   docker cp "5. Usuarios.cql" mype-cass1:/tmp/5_Usuarios.cql
--   docker exec -it mype-cass1 cqlsh -u cassandra -f /tmp/5_Usuarios.cql   (pide la clave)
-- Los usuarios con contrasena se crean con "5b_Usuarios.sh" (las claves
-- no se guardan en archivos).
--
-- Diferencias con Oracle: Cassandra no tiene perfiles de contrasena
-- (PERFIL_MYPE) ni PASSWORD EXPIRE, y no distingue roles por defecto
-- vs activos; por eso al admin se le da AUTHORIZE sobre los roles
-- funcionales (equivale a WITH ADMIN OPTION).
-- ============================================================

CREATE ROLE IF NOT EXISTS admin_oracle;
CREATE ROLE IF NOT EXISTS gestor_compras_oracle;
CREATE ROLE IF NOT EXISTS gestor_ventas_oracle;
CREATE ROLE IF NOT EXISTS analista_oracle;
CREATE ROLE IF NOT EXISTS consulta_oracle;

-- admin_oracle: administra roles, sin MODIFY ni ALL PERMISSIONS
GRANT CREATE   ON ALL ROLES TO admin_oracle;
GRANT ALTER    ON ALL ROLES TO admin_oracle;
GRANT DESCRIBE ON ALL ROLES TO admin_oracle;
GRANT AUTHORIZE ON ROLE gestor_compras_oracle TO admin_oracle;
GRANT AUTHORIZE ON ROLE gestor_ventas_oracle  TO admin_oracle;
GRANT AUTHORIZE ON ROLE analista_oracle       TO admin_oracle;
GRANT AUTHORIZE ON ROLE consulta_oracle       TO admin_oracle;
GRANT SELECT ON KEYSPACE mype_cassandra TO admin_oracle;

-- gestor_compras_oracle: lee reabastecimiento e inventario
GRANT SELECT ON mype_cassandra.alertas_por_sucursal     TO gestor_compras_oracle;
GRANT SELECT ON mype_cassandra.movimientos_por_sku      TO gestor_compras_oracle;
GRANT SELECT ON mype_cassandra.historial_stock_por_sku  TO gestor_compras_oracle;

-- gestor_ventas_oracle: lee y modifica ventas; lee inventario
GRANT SELECT ON mype_cassandra.ventas_por_sucursal_dia  TO gestor_ventas_oracle;
GRANT MODIFY ON mype_cassandra.ventas_por_sucursal_dia  TO gestor_ventas_oracle;
GRANT SELECT ON mype_cassandra.ventas_por_cliente       TO gestor_ventas_oracle;
GRANT MODIFY ON mype_cassandra.ventas_por_cliente       TO gestor_ventas_oracle;
GRANT SELECT ON mype_cassandra.movimientos_por_sku      TO gestor_ventas_oracle;
GRANT SELECT ON mype_cassandra.historial_stock_por_sku  TO gestor_ventas_oracle;
GRANT SELECT ON mype_cassandra.alertas_por_sucursal     TO gestor_ventas_oracle;

-- analista_oracle: sin ventas_por_cliente (como en Oracle no ve Cliente)
GRANT SELECT ON mype_cassandra.ventas_por_sucursal_dia  TO analista_oracle;
GRANT SELECT ON mype_cassandra.movimientos_por_sku      TO analista_oracle;
GRANT SELECT ON mype_cassandra.historial_stock_por_sku  TO analista_oracle;
GRANT SELECT ON mype_cassandra.alertas_por_sucursal     TO analista_oracle;

-- consulta_oracle: solo lectura en todo el keyspace
GRANT SELECT ON KEYSPACE mype_cassandra TO consulta_oracle;
