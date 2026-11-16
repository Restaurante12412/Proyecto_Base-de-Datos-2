-- =====================================================================
-- MypeInventario - PostgreSQL
-- 4. Procedimientos y funciones
-- Ejecutar conectado a la base "MypeInventario", despues de "2. Tablas.sql":
--   psql -U postgres -d "MypeInventario" -f "4. Procedure_Functions.sql"
--
--   1. sp_registrar_movimiento    (procedimiento) registrar movimientos
--   2. fn_consultar_existencias   (funcion)       consultar existencias
--   3. sp_controlar_stock_minimo  (procedimiento) controlar stock minimo
--   4. fn_reporte_movimientos     (funcion)       reporte de movimientos
--   5. fn_reporte_stock_almacen   (funcion)       reporte de stock por almacen
--
-- Todos se ejecutan con los permisos del usuario que los llama
-- (SECURITY INVOKER, valor por defecto): un usuario sin permiso sobre las
-- tablas no puede usarlos para saltarse su rol.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. sp_registrar_movimiento
--    Integrante responsable: (completar)
--    Registra una entrada (cantidad positiva) o una salida (cantidad
--    negativa) sobre un registro de Stock. En una sola transaccion:
--    inserta el movimiento, actualiza el stock y deja el cambio en
--    HistorialStock. Rechaza la operacion si el stock quedaria por debajo
--    de la cantidad reservada.
--    Si el tipo de movimiento no afecta stock, solo registra el movimiento.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_movimiento(
    p_id_stock            BIGINT,
    p_id_tipo_movimiento  INTEGER,
    p_cantidad            NUMERIC,
    p_observacion         VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_afecta     BOOLEAN;
    v_actual     NUMERIC(12,2);
    v_reservada  NUMERIC(12,2);
    v_nueva      NUMERIC(12,2);
BEGIN
    IF p_cantidad IS NULL OR p_cantidad = 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser distinta de cero';
    END IF;

    SELECT t.afecta_stock INTO v_afecta
    FROM TipoMovimiento t
    WHERE t.id_tipo_movimiento = p_id_tipo_movimiento;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el tipo de movimiento %', p_id_tipo_movimiento;
    END IF;

    -- Bloquea la fila de stock para evitar dos movimientos simultaneos
    SELECT s.cantidad_actual, s.cantidad_reservada INTO v_actual, v_reservada
    FROM Stock s
    WHERE s.id_stock = p_id_stock
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el registro de stock %', p_id_stock;
    END IF;

    IF v_afecta THEN
        v_nueva := v_actual + p_cantidad;
        IF v_nueva < v_reservada THEN
            RAISE EXCEPTION 'Stock insuficiente: actual %, reservado %, movimiento %',
                v_actual, v_reservada, p_cantidad;
        END IF;
    END IF;

    INSERT INTO MovimientoInventario (id_stock, id_tipo_movimiento, cantidad, observacion)
    VALUES (p_id_stock, p_id_tipo_movimiento, p_cantidad, p_observacion);

    IF v_afecta THEN
        UPDATE Stock
        SET cantidad_actual     = v_nueva,
            cantidad_disponible = v_nueva - v_reservada,
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id_stock = p_id_stock;

        INSERT INTO HistorialStock (id_stock, cantidad_anterior, cantidad_nueva, motivo)
        VALUES (p_id_stock, v_actual, v_nueva,
                COALESCE(p_observacion, 'Movimiento de inventario'));
    END IF;
END;
$$;

-- Ejemplo de uso:
--   CALL sp_registrar_movimiento(1, 1, 25, 'Ingreso por compra');
--   CALL sp_registrar_movimiento(1, 2, -5, 'Salida por venta');


-- ---------------------------------------------------------------------
-- 2. fn_consultar_existencias
--    Integrante responsable: (completar)
--    Devuelve las existencias de un SKU por almacen y ubicacion.
--    Si se indica el almacen, filtra solo ese almacen.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_consultar_existencias(
    p_id_sku      BIGINT,
    p_id_almacen  BIGINT DEFAULT NULL
)
RETURNS TABLE (
    id_almacen           BIGINT,
    almacen              VARCHAR,
    codigo_ubicacion     VARCHAR,
    cantidad_actual      NUMERIC,
    cantidad_reservada   NUMERIC,
    cantidad_disponible  NUMERIC,
    fecha_actualizacion  TIMESTAMP
)
LANGUAGE sql
STABLE
AS $$
    SELECT a.id_almacen, a.nombre, u.codigo_ubicacion,
           s.cantidad_actual, s.cantidad_reservada, s.cantidad_disponible,
           s.fecha_actualizacion
    FROM Stock s
    JOIN UbicacionProducto u ON u.id_ubicacion = s.id_ubicacion
    JOIN Almacen a           ON a.id_almacen   = u.id_almacen
    WHERE s.id_sku = p_id_sku
      AND (p_id_almacen IS NULL OR a.id_almacen = p_id_almacen)
    ORDER BY a.nombre, u.codigo_ubicacion;
$$;

-- Ejemplo de uso:
--   SELECT * FROM fn_consultar_existencias(1);
--   SELECT * FROM fn_consultar_existencias(1, 2);


-- ---------------------------------------------------------------------
-- 3. sp_controlar_stock_minimo
--    Integrante responsable: (completar)
--    Compara la cantidad disponible de cada registro de Stock con el
--    stock minimo de su configuracion activa:
--      - si esta por debajo y no hay alerta pendiente, crea la alerta;
--      - si ya se recupero, marca la alerta pendiente como RESUELTA.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_controlar_stock_minimo()
LANGUAGE plpgsql
AS $$
DECLARE
    v_creadas    INTEGER;
    v_resueltas  INTEGER;
BEGIN
    INSERT INTO AlertaReabastecimiento (id_stock, id_configuracion, cantidad_detectada)
    SELECT s.id_stock, c.id_configuracion, s.cantidad_disponible
    FROM Stock s
    JOIN ConfiguracionReabastecimiento c
      ON c.id_sku = s.id_sku AND c.estado = 'ACTIVO'
    WHERE s.cantidad_disponible < c.stock_minimo
      AND NOT EXISTS (
            SELECT 1
            FROM AlertaReabastecimiento al
            WHERE al.id_stock = s.id_stock
              AND al.id_configuracion = c.id_configuracion
              AND al.estado = 'PENDIENTE');
    GET DIAGNOSTICS v_creadas = ROW_COUNT;

    UPDATE AlertaReabastecimiento al
    SET estado = 'RESUELTA',
        fecha_resolucion = CURRENT_TIMESTAMP
    FROM Stock s, ConfiguracionReabastecimiento c
    WHERE al.estado = 'PENDIENTE'
      AND s.id_stock = al.id_stock
      AND c.id_configuracion = al.id_configuracion
      AND s.cantidad_disponible >= c.stock_minimo;
    GET DIAGNOSTICS v_resueltas = ROW_COUNT;

    RAISE NOTICE 'Alertas creadas: %, alertas resueltas: %', v_creadas, v_resueltas;
END;
$$;

-- Ejemplo de uso:
--   CALL sp_controlar_stock_minimo();
--   SELECT * FROM AlertaReabastecimiento WHERE estado = 'PENDIENTE';


-- ---------------------------------------------------------------------
-- 4. fn_reporte_movimientos
--    Integrante responsable: (completar)
--    Reporte de movimientos entre dos fechas, agrupado por almacen y
--    tipo de movimiento: numero de movimientos, entradas y salidas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_reporte_movimientos(
    p_desde  TIMESTAMP,
    p_hasta  TIMESTAMP
)
RETURNS TABLE (
    almacen          VARCHAR,
    tipo_movimiento  VARCHAR,
    movimientos      BIGINT,
    entradas         NUMERIC,
    salidas          NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT a.nombre, t.nombre,
           count(*),
           COALESCE(sum(m.cantidad) FILTER (WHERE m.cantidad > 0), 0),
           COALESCE(-sum(m.cantidad) FILTER (WHERE m.cantidad < 0), 0)
    FROM MovimientoInventario m
    JOIN TipoMovimiento t    ON t.id_tipo_movimiento = m.id_tipo_movimiento
    JOIN Stock s             ON s.id_stock     = m.id_stock
    JOIN UbicacionProducto u ON u.id_ubicacion = s.id_ubicacion
    JOIN Almacen a           ON a.id_almacen   = u.id_almacen
    WHERE m.fecha_movimiento >= p_desde
      AND m.fecha_movimiento <  p_hasta
    GROUP BY a.nombre, t.nombre
    ORDER BY a.nombre, t.nombre;
$$;

-- Ejemplo de uso:
--   SELECT * FROM fn_reporte_movimientos('2026-11-01', '2026-12-01');


-- ---------------------------------------------------------------------
-- 5. fn_reporte_stock_almacen
--    Integrante responsable: (completar)
--    Resumen del inventario por almacen: SKU distintos, unidades totales,
--    unidades disponibles y cuantos registros estan bajo el stock minimo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_reporte_stock_almacen()
RETURNS TABLE (
    id_almacen            BIGINT,
    almacen               VARCHAR,
    skus                  BIGINT,
    unidades_actuales     NUMERIC,
    unidades_disponibles  NUMERIC,
    bajo_stock_minimo     BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT a.id_almacen, a.nombre,
           count(DISTINCT s.id_sku),
           COALESCE(sum(s.cantidad_actual), 0),
           COALESCE(sum(s.cantidad_disponible), 0),
           count(*) FILTER (WHERE EXISTS (
                SELECT 1
                FROM ConfiguracionReabastecimiento c
                WHERE c.id_sku = s.id_sku
                  AND c.estado = 'ACTIVO'
                  AND s.cantidad_disponible < c.stock_minimo))
    FROM Almacen a
    LEFT JOIN UbicacionProducto u ON u.id_almacen   = a.id_almacen
    LEFT JOIN Stock s             ON s.id_ubicacion = u.id_ubicacion
    GROUP BY a.id_almacen, a.nombre
    ORDER BY a.nombre;
$$;

-- Ejemplo de uso:
--   SELECT * FROM fn_reporte_stock_almacen();
