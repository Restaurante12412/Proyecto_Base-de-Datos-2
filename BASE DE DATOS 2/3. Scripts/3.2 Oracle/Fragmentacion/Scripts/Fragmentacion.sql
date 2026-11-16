-- MypeInventario - ORACLE
-- Fragmentacion horizontal de VENTA (particionamiento compuesto)
-- Datos: fecha_venta entre 15/08/2026 y 12/11/2026, 20 sucursales distintas.
-- Con particiones anuales todo cae en p_2026; por eso se pasa a particiones MENSUALES.
-- Conexion: MYPE_INVENTARIO. Ejecutar despues de "6. Data.sql" y "3. Indices.sql".
-- ALTER TABLE ... MODIFY PARTITION BY convierte la tabla ya cargada en particionada (en linea).

------------------------------------------------------------------
-- VARIANTE A (RECOMENDADA, la mas simple): RANGE mensual + HASH por id_sucursal
------------------------------------------------------------------
ALTER TABLE venta MODIFY
  PARTITION BY RANGE (fecha_venta)
  SUBPARTITION BY HASH (id_sucursal)
  SUBPARTITION TEMPLATE (
    SUBPARTITION s_h1,
    SUBPARTITION s_h2,
    SUBPARTITION s_h3,
    SUBPARTITION s_h4
  )
  (
    PARTITION p_antes   VALUES LESS THAN (DATE '2026-08-01'),
    PARTITION p_2026_08 VALUES LESS THAN (DATE '2026-09-01'),
    PARTITION p_2026_09 VALUES LESS THAN (DATE '2026-10-01'),
    PARTITION p_2026_10 VALUES LESS THAN (DATE '2026-11-01'),
    PARTITION p_2026_11 VALUES LESS THAN (DATE '2026-12-01'),
    PARTITION p_max     VALUES LESS THAN (MAXVALUE)
  )
  ONLINE;

------------------------------------------------------------------
-- VARIANTE B (alternativa): RANGE mensual + LIST por sucursal
-- Con solo 20 sucursales es viable. Genera la lista sola desde los datos
-- y agrega una subparticion DEFAULT para sucursales futuras.
-- Si ya ejecutaste la variante A, esto vuelve a re-particionar.
------------------------------------------------------------------
/*
DECLARE
  v_lista VARCHAR2(4000);
  v_sql   VARCHAR2(8000);
BEGIN
  SELECT LISTAGG('SUBPARTITION s_suc' || id_sucursal || ' VALUES (' || id_sucursal || ')', ', ')
         WITHIN GROUP (ORDER BY id_sucursal)
  INTO v_lista
  FROM (SELECT DISTINCT id_sucursal FROM venta);

  v_sql := 'ALTER TABLE venta MODIFY PARTITION BY RANGE (fecha_venta) '
        || 'SUBPARTITION BY LIST (id_sucursal) '
        || 'SUBPARTITION TEMPLATE (' || v_lista || ', SUBPARTITION s_default VALUES (DEFAULT)) '
        || '(PARTITION p_antes   VALUES LESS THAN (DATE ''2026-08-01''), '
        || ' PARTITION p_2026_08 VALUES LESS THAN (DATE ''2026-09-01''), '
        || ' PARTITION p_2026_09 VALUES LESS THAN (DATE ''2026-10-01''), '
        || ' PARTITION p_2026_10 VALUES LESS THAN (DATE ''2026-11-01''), '
        || ' PARTITION p_2026_11 VALUES LESS THAN (DATE ''2026-12-01''), '
        || ' PARTITION p_max     VALUES LESS THAN (MAXVALUE)) ONLINE';
  EXECUTE IMMEDIATE v_sql;
END;
/
*/

------------------------------------------------------------------
-- DESPUES DE PARTICIONAR
------------------------------------------------------------------
ALTER TABLE venta ENABLE ROW MOVEMENT;

-- El indice idx_venta_sucursal_fecha debe seguir YES / LOCAL; el PK, NO
SELECT i.index_name, i.partitioned, p.locality
FROM user_indexes i LEFT JOIN user_part_indexes p ON p.index_name = i.index_name
WHERE i.table_name = 'VENTA';

BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER, 'VENTA', granularity => 'ALL'); END;
/

------------------------------------------------------------------
-- EVIDENCIAS
------------------------------------------------------------------
-- Particiones (filas por mes)
SELECT partition_name, subpartition_count, num_rows, high_value
FROM user_tab_partitions WHERE table_name = 'VENTA' ORDER BY partition_position;

-- Subparticiones (reparto por fragmento)
SELECT partition_name, subpartition_name, num_rows
FROM user_tab_subpartitions WHERE table_name = 'VENTA'
ORDER BY partition_name, subpartition_position;

-- Sin perdida de filas (deben coincidir)
SELECT COUNT(*) AS total_venta FROM venta;
SELECT SUM(num_rows) AS total_fragmentos FROM user_tab_subpartitions WHERE table_name = 'VENTA';

-- Pruning: octubre 2026 + una sucursal  (esperado: RANGE SINGLE + HASH/LIST SINGLE)
EXPLAIN PLAN FOR
  SELECT id_venta, fecha_venta, total FROM venta
  WHERE id_sucursal = 1
    AND fecha_venta >= DATE '2026-10-01' AND fecha_venta < DATE '2026-11-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Sin filtrar por la clave (esperado: RANGE ALL + HASH/LIST ALL)
EXPLAIN PLAN FOR SELECT * FROM venta WHERE total > 100;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- FK hacia Venta siguen validas (DetalleVenta, MetodoPago, VentaCanal)
SELECT constraint_name, table_name, status FROM user_constraints
WHERE r_constraint_name = (SELECT constraint_name FROM user_constraints
                           WHERE table_name = 'VENTA' AND constraint_type = 'P');
