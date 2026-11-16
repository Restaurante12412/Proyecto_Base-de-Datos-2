-- MypeInventario - CASSANDRA
-- 1. Esquema: keyspace con replicacion y las 5 tablas
-- Cluster: MypeCluster (mype-cass1, mype-cass2, mype-cass3), datacenter dc1.
-- Ejecucion:
--   docker cp "1. Esquema.cql" mype-cass1:/tmp/1_Esquema.cql
--   docker exec mype-cass1 cqlsh -f /tmp/1_Esquema.cql
-- (con la autenticacion activa: docker exec -it mype-cass1 cqlsh -u cassandra -f /tmp/1_Esquema.cql)

------------------------------------------------------------------
-- KEYSPACE
-- NetworkTopologyStrategy con 3 replicas en dc1: cada dato queda en los 3 nodos.
-- durable_writes = true: toda escritura pasa por el commit log.
------------------------------------------------------------------
CREATE KEYSPACE IF NOT EXISTS mype_cassandra
  WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3}
  AND durable_writes = true;

USE mype_cassandra;

------------------------------------------------------------------
-- 1. movimientos_por_sku
-- Pregunta: que entradas y salidas tuvo un SKU en una sucursal durante un mes?
-- Particion por (sucursal, sku, mes) para que ninguna particion crezca sin limite.
------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS movimientos_por_sku (
  id_sucursal         bigint,
  id_sku              bigint,
  anio_mes            int,          -- formato AAAAMM, por ejemplo 202611
  fecha_movimiento    timestamp,
  id_movimiento       bigint,
  id_stock            bigint,
  id_tipo_movimiento  int,
  tipo_movimiento     text,
  afecta_stock        boolean,
  cantidad            decimal,
  observacion         text,
  PRIMARY KEY ((id_sucursal, id_sku, anio_mes), fecha_movimiento, id_movimiento)
) WITH CLUSTERING ORDER BY (fecha_movimiento DESC, id_movimiento DESC);

------------------------------------------------------------------
-- 2. historial_stock_por_sku
-- Pregunta: como evoluciono el stock de un SKU en un almacen?
------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS historial_stock_por_sku (
  id_sku            bigint,
  id_almacen        bigint,
  anio              int,
  fecha_cambio      timestamp,
  id_historial      bigint,
  id_stock          bigint,
  cantidad_anterior decimal,
  cantidad_nueva    decimal,
  motivo            text,
  PRIMARY KEY ((id_sku, id_almacen, anio), fecha_cambio, id_historial)
) WITH CLUSTERING ORDER BY (fecha_cambio DESC, id_historial DESC);

------------------------------------------------------------------
-- 3. alertas_por_sucursal
-- Pregunta: que alertas de reabastecimiento tiene pendientes cada sucursal?
-- Al resolver una alerta se borra de su estado y se inserta en el nuevo (BATCH).
------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alertas_por_sucursal (
  id_sucursal              bigint,
  estado                   text,
  fecha_alerta             timestamp,
  id_alerta                bigint,
  id_stock                 bigint,
  id_sku                   bigint,
  id_configuracion         bigint,
  cantidad_detectada       decimal,
  stock_minimo             decimal,
  cantidad_reabastecimiento decimal,
  fecha_resolucion         timestamp,
  PRIMARY KEY ((id_sucursal, estado), fecha_alerta, id_alerta)
) WITH CLUSTERING ORDER BY (fecha_alerta DESC, id_alerta DESC);

------------------------------------------------------------------
-- 4. ventas_por_sucursal_dia
-- Pregunta: cuanto vendio una sucursal en un dia y cuales fueron sus ventas?
------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ventas_por_sucursal_dia (
  id_sucursal  bigint,
  fecha_dia    date,
  fecha_venta  timestamp,
  id_venta     bigint,
  id_cliente   bigint,        -- puede ser nulo (venta de mostrador)
  id_empleado  bigint,
  canal        text,
  estado       text,
  num_items    int,
  subtotal     decimal,
  descuento    decimal,
  impuesto     decimal,
  total        decimal,
  PRIMARY KEY ((id_sucursal, fecha_dia), fecha_venta, id_venta)
) WITH CLUSTERING ORDER BY (fecha_venta ASC, id_venta ASC);

------------------------------------------------------------------
-- 5. ventas_por_cliente
-- Pregunta: que compro un cliente y cuando? (solo ventas con cliente)
------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ventas_por_cliente (
  id_cliente   bigint,
  fecha_venta  timestamp,
  id_venta     bigint,
  id_sucursal  bigint,
  canal        text,
  estado       text,
  num_items    int,
  total        decimal,
  PRIMARY KEY ((id_cliente), fecha_venta, id_venta)
) WITH CLUSTERING ORDER BY (fecha_venta DESC, id_venta DESC);

------------------------------------------------------------------
-- VERIFICACION
------------------------------------------------------------------
DESCRIBE KEYSPACE mype_cassandra;
