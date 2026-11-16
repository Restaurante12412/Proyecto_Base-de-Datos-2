-- ============================================================
-- 2b. Exportar_Oracle.sql
-- Conexion: MYPE_INVENTARIO (SQL Developer).
-- Ejecutar cada consulta y exportar el resultado a CSV (con encabezado)
-- con el nombre indicado. Luego copiarlos a Downloads y usar "2a. Cargar_Data.sh".
-- Se exportan solo las sucursales 1 a 4 (100 ventas por tabla).
-- ============================================================

-- Archivo: ventas_sucursal_dia.csv  (tabla 4: ventas_por_sucursal_dia)
SELECT v.id_sucursal,
       TO_CHAR(v.fecha_venta,'YYYY-MM-DD')            AS fecha_dia,
       TO_CHAR(v.fecha_venta,'YYYY-MM-DD HH24:MI:SS') AS fecha_venta,
       v.id_venta,
       v.id_cliente,
       v.id_empleado,
       (SELECT MIN(c.nombre)
          FROM ventacanal vc JOIN canalventa c ON c.id_canal = vc.id_canal
         WHERE vc.id_venta = v.id_venta)               AS canal,
       v.estado,
       (SELECT COUNT(*) FROM detalleventa d WHERE d.id_venta = v.id_venta) AS num_items,
       TO_CHAR(v.subtotal,  'FM9999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,''') AS subtotal,
       TO_CHAR(v.descuento, 'FM9999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,''') AS descuento,
       TO_CHAR(v.impuesto,  'FM9999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,''') AS impuesto,
       TO_CHAR(v.total,     'FM9999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,''') AS total
FROM venta v
WHERE v.id_sucursal IN (1,2,3,4)
ORDER BY v.id_sucursal, v.fecha_venta, v.id_venta;

-- Archivo: ventas_cliente.csv  (tabla 5: ventas_por_cliente; solo ventas con cliente)
SELECT v.id_cliente,
       TO_CHAR(v.fecha_venta,'YYYY-MM-DD HH24:MI:SS') AS fecha_venta,
       v.id_venta,
       v.id_sucursal,
       (SELECT MIN(c.nombre)
          FROM ventacanal vc JOIN canalventa c ON c.id_canal = vc.id_canal
         WHERE vc.id_venta = v.id_venta)               AS canal,
       v.estado,
       (SELECT COUNT(*) FROM detalleventa d WHERE d.id_venta = v.id_venta) AS num_items,
       TO_CHAR(v.total, 'FM9999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,''') AS total
FROM venta v
WHERE v.id_sucursal IN (1,2,3,4)
  AND v.id_cliente IS NOT NULL
ORDER BY v.id_cliente, v.fecha_venta, v.id_venta;
