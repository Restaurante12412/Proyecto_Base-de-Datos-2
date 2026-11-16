-- =====================================================================
-- MypeInventario - ORACLE
-- 4. Procedimientos y funciones (PL/SQL)
-- Ejecutar conectado como MYPE_INVENTARIO, despues de "2. Tablas.sql":
--   sqlplus MYPE_INVENTARIO@localhost:1521/FREEPDB1 @"4. Procedure_Functions.sql"
--
--   1. sp_registrar_detalle_venta    (procedimiento) registrar un item de venta
--   2. sp_anular_venta               (procedimiento) anular una venta
--   3. fn_total_ventas_sucursal      (funcion)       total vendido por sucursal
--   4. sp_reporte_ventas_canal       (procedimiento) reporte de ventas por canal y dia
--   5. sp_reporte_compras_proveedor  (procedimiento) reporte de compras por proveedor
--
-- Ningun procedimiento hace COMMIT: la aplicacion (o quien lo ejecuta)
-- confirma o deshace la transaccion completa.
-- =====================================================================
SET SERVEROUTPUT ON


-- ---------------------------------------------------------------------
-- 1. sp_registrar_detalle_venta
--    Integrante responsable: (completar)
--    Agrega un item a una venta en estado REGISTRADA: toma el precio de
--    venta vigente del SKU, calcula el subtotal del item y recalcula los
--    totales de la cabecera (subtotal, descuento y total). El impuesto de
--    la cabecera no se modifica.
--      Venta.subtotal  = suma de cantidad x precio_unitario
--      Venta.descuento = suma de los descuentos de los items
--      Venta.total     = subtotal - descuento + impuesto
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_detalle_venta (
    p_id_venta   IN NUMBER,
    p_id_sku     IN NUMBER,
    p_cantidad   IN NUMBER,
    p_descuento  IN NUMBER DEFAULT 0
) AS
    v_estado_venta  Venta.estado%TYPE;
    v_impuesto      Venta.impuesto%TYPE;
    v_estado_sku    VarianteSKU.estado%TYPE;
    v_precio        VarianteSKU.precio_venta%TYPE;
    v_bruto         NUMBER(12,2);
    v_subtotal      NUMBER(12,2);
    v_descuento     NUMBER(12,2);
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE_APPLICATION_ERROR(-20010, 'La cantidad debe ser mayor que cero');
    END IF;
    IF p_descuento IS NULL OR p_descuento < 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El descuento no puede ser negativo');
    END IF;

    -- Bloquea la cabecera para evitar recalculos simultaneos
    BEGIN
        SELECT estado, impuesto INTO v_estado_venta, v_impuesto
        FROM Venta
        WHERE id_venta = p_id_venta
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012, 'No existe la venta ' || p_id_venta);
    END;
    IF v_estado_venta <> 'REGISTRADA' THEN
        RAISE_APPLICATION_ERROR(-20013, 'La venta ' || p_id_venta || ' esta ' || v_estado_venta);
    END IF;

    BEGIN
        SELECT estado, precio_venta INTO v_estado_sku, v_precio
        FROM VarianteSKU
        WHERE id_sku = p_id_sku;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20014, 'No existe el SKU ' || p_id_sku);
    END;
    IF v_estado_sku <> 'ACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20015, 'El SKU ' || p_id_sku || ' esta ' || v_estado_sku);
    END IF;

    v_bruto := ROUND(p_cantidad * v_precio, 2);
    IF p_descuento > v_bruto THEN
        RAISE_APPLICATION_ERROR(-20016, 'El descuento supera el importe del item');
    END IF;

    INSERT INTO DetalleVenta (id_venta, id_sku, cantidad, precio_unitario, descuento, subtotal)
    VALUES (p_id_venta, p_id_sku, p_cantidad, v_precio, p_descuento, v_bruto - p_descuento);

    SELECT NVL(SUM(ROUND(cantidad * precio_unitario, 2)), 0), NVL(SUM(descuento), 0)
    INTO v_subtotal, v_descuento
    FROM DetalleVenta
    WHERE id_venta = p_id_venta;

    UPDATE Venta
    SET subtotal  = v_subtotal,
        descuento = v_descuento,
        total     = v_subtotal - v_descuento + v_impuesto
    WHERE id_venta = p_id_venta;
END sp_registrar_detalle_venta;
/
SHOW ERRORS

-- Ejemplo de uso:
--   EXEC sp_registrar_detalle_venta(1, 1, 2);
--   EXEC sp_registrar_detalle_venta(1, 2, 1, 5);
--   SELECT subtotal, descuento, impuesto, total FROM Venta WHERE id_venta = 1;


-- ---------------------------------------------------------------------
-- 2. sp_anular_venta
--    Integrante responsable: (completar)
--    Cambia una venta de REGISTRADA a ANULADA. No borra la venta ni su
--    detalle, para conservar el historial. Rechaza la operacion si la
--    venta no existe o ya estaba anulada.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_anular_venta (
    p_id_venta  IN NUMBER
) AS
    v_estado  Venta.estado%TYPE;
BEGIN
    BEGIN
        SELECT estado INTO v_estado
        FROM Venta
        WHERE id_venta = p_id_venta
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20020, 'No existe la venta ' || p_id_venta);
    END;
    IF v_estado = 'ANULADA' THEN
        RAISE_APPLICATION_ERROR(-20021, 'La venta ' || p_id_venta || ' ya estaba anulada');
    END IF;

    UPDATE Venta
    SET estado = 'ANULADA'
    WHERE id_venta = p_id_venta;
END sp_anular_venta;
/
SHOW ERRORS

-- Ejemplo de uso:
--   EXEC sp_anular_venta(1);
--   SELECT id_venta, estado FROM Venta WHERE id_venta = 1;


-- ---------------------------------------------------------------------
-- 3. fn_total_ventas_sucursal
--    Integrante responsable: (completar)
--    Devuelve el total vendido por una sucursal entre dos fechas (ambas
--    incluidas). No cuenta las ventas anuladas. Devuelve 0 si no hay ventas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_ventas_sucursal (
    p_id_sucursal  IN NUMBER,
    p_desde        IN DATE,
    p_hasta        IN DATE
) RETURN NUMBER AS
    v_total  NUMBER(14,2);
BEGIN
    SELECT NVL(SUM(total), 0) INTO v_total
    FROM Venta
    WHERE id_sucursal = p_id_sucursal
      AND estado = 'REGISTRADA'
      AND fecha_venta >= TRUNC(p_desde)
      AND fecha_venta <  TRUNC(p_hasta) + 1;
    RETURN v_total;
END fn_total_ventas_sucursal;
/
SHOW ERRORS

-- Ejemplo de uso:
--   SELECT fn_total_ventas_sucursal(1, DATE '2026-11-01', DATE '2026-11-30') AS total FROM dual;


-- ---------------------------------------------------------------------
-- 4. sp_reporte_ventas_canal
--    Integrante responsable: (completar)
--    Reporte de ventas por dia y canal entre dos fechas (ambas incluidas):
--    numero de ventas e importe. No cuenta las ventas anuladas.
--    Devuelve el resultado en un cursor.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_reporte_ventas_canal (
    p_desde      IN  DATE,
    p_hasta      IN  DATE,
    p_resultado  OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_resultado FOR
        SELECT TRUNC(v.fecha_venta) AS dia,
               c.nombre             AS canal,
               COUNT(*)             AS ventas,
               SUM(v.total)         AS importe
        FROM Venta v
        JOIN VentaCanal vc ON vc.id_venta = v.id_venta
        JOIN CanalVenta c  ON c.id_canal  = vc.id_canal
        WHERE v.estado = 'REGISTRADA'
          AND v.fecha_venta >= TRUNC(p_desde)
          AND v.fecha_venta <  TRUNC(p_hasta) + 1
        GROUP BY TRUNC(v.fecha_venta), c.nombre
        ORDER BY TRUNC(v.fecha_venta), c.nombre;
END sp_reporte_ventas_canal;
/
SHOW ERRORS

-- Ejemplo de uso (SQL*Plus o SQL Developer, "Ejecutar script"):
--   VARIABLE rc REFCURSOR
--   EXEC sp_reporte_ventas_canal(DATE '2026-11-01', DATE '2026-11-30', :rc);
--   PRINT rc


-- ---------------------------------------------------------------------
-- 5. sp_reporte_compras_proveedor
--    Integrante responsable: (completar)
--    Reporte de compras por proveedor entre dos fechas (ambas incluidas):
--    numero de compras, importe y fecha de la ultima compra. No cuenta las
--    compras anuladas. Devuelve el resultado en un cursor.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_reporte_compras_proveedor (
    p_desde      IN  DATE,
    p_hasta      IN  DATE,
    p_resultado  OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_resultado FOR
        SELECT p.id_proveedor,
               p.razon_social,
               COUNT(*)            AS compras,
               SUM(c.total)        AS importe,
               MAX(c.fecha_compra) AS ultima_compra
        FROM Compra c
        JOIN Proveedor p ON p.id_proveedor = c.id_proveedor
        WHERE c.estado = 'REGISTRADA'
          AND c.fecha_compra >= TRUNC(p_desde)
          AND c.fecha_compra <  TRUNC(p_hasta) + 1
        GROUP BY p.id_proveedor, p.razon_social
        ORDER BY SUM(c.total) DESC;
END sp_reporte_compras_proveedor;
/
SHOW ERRORS

-- Ejemplo de uso (SQL*Plus o SQL Developer, "Ejecutar script"):
--   VARIABLE rc REFCURSOR
--   EXEC sp_reporte_compras_proveedor(DATE '2026-08-01', DATE '2026-11-30', :rc);
--   PRINT rc


-- ---------------------------------------------------------------------
-- VERIFICACION: los 5 objetos deben aparecer con estado VALID
-- ---------------------------------------------------------------------
COLUMN object_name FORMAT A32
COLUMN object_type FORMAT A12
COLUMN status FORMAT A8

SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PROCEDURE', 'FUNCTION')
ORDER BY object_type, object_name;


-- ---------------------------------------------------------------------
-- PERMISOS DE EJECUCION
-- Los usuarios del proyecto solo pueden ejecutar estos objetos si se les
-- otorga EXECUTE. Los roles se crean en el script de usuarios, por lo que
-- este bloque se ejecuta DESPUES de ese script. Descomentar y ejecutar
-- como MYPE_INVENTARIO.
-- ---------------------------------------------------------------------
-- GRANT EXECUTE ON sp_registrar_detalle_venta   TO GESTOR_VENTAS_ORACLE;
-- GRANT EXECUTE ON sp_anular_venta              TO GESTOR_VENTAS_ORACLE;
-- GRANT EXECUTE ON fn_total_ventas_sucursal     TO GESTOR_VENTAS_ORACLE, ANALISTA_ORACLE, CONSULTA_ORACLE;
-- GRANT EXECUTE ON sp_reporte_ventas_canal      TO GESTOR_VENTAS_ORACLE, ANALISTA_ORACLE, CONSULTA_ORACLE;
-- GRANT EXECUTE ON sp_reporte_compras_proveedor TO GESTOR_COMPRAS_ORACLE, ANALISTA_ORACLE, CONSULTA_ORACLE;
