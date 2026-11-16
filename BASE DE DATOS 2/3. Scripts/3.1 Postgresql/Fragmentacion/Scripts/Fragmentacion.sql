-- =====================================================================
-- MypeInventario - PostgreSQL
-- 8. Fragmentacion horizontal (particionamiento declarativo por LIST)
-- Ejecutar en pgAdmin (Query Tool) conectado a "MypeInventario" como
-- postgres. Se puede ejecutar completo con F5; para las capturas, correr
-- por separado cada bloque de la seccion 3 (VERIFICACION).
--
-- CRITERIO: id_sucursal (campo de ubicacion de la operacion).
--   Inventario es la unica tabla de PostgreSQL que guarda id_sucursal; el
--   resto de tablas llega a la sucursal a traves de Almacen -> Inventario
--   (fragmentacion derivada, solo conceptual).
-- ESQUEMA: LIST por grupos de sucursales cercanas (zonas), mas DEFAULT:
--   inventario_zona1 : sucursales 1 a 5
--   inventario_zona2 : sucursales 6 a 10
--   inventario_zona3 : sucursales 11 a 15
--   inventario_zona4 : sucursales 16 a 20
--   inventario_otras : cualquier sucursal nueva (DEFAULT)
--
-- DECISION DE DISENO: se crea una copia fragmentada en el esquema
-- "fragmentacion" y NO se altera public.inventario. Una tabla particionada
-- exige que su clave primaria incluya la clave de particion
-- (id_inventario, id_sucursal), y Almacen referencia solo id_inventario;
-- convertir public.inventario en tabla particionada obligaria a eliminar la
-- FK fk_almacen_inventario o a agregar id_sucursal a Almacen. Se deja como
-- punto a defender en el informe.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ESTRUCTURA
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS fragmentacion;

CREATE TABLE fragmentacion.inventario_frag (
    id_inventario   BIGINT NOT NULL,
    id_sucursal     BIGINT NOT NULL,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     VARCHAR(250),
    estado          VARCHAR(20) NOT NULL DEFAULT 'ACTIVO'
                        CHECK (estado IN ('ACTIVO','INACTIVO')),
    PRIMARY KEY (id_inventario, id_sucursal)
) PARTITION BY LIST (id_sucursal);

CREATE TABLE fragmentacion.inventario_zona1 PARTITION OF fragmentacion.inventario_frag
    FOR VALUES IN (1, 2, 3, 4, 5);
CREATE TABLE fragmentacion.inventario_zona2 PARTITION OF fragmentacion.inventario_frag
    FOR VALUES IN (6, 7, 8, 9, 10);
CREATE TABLE fragmentacion.inventario_zona3 PARTITION OF fragmentacion.inventario_frag
    FOR VALUES IN (11, 12, 13, 14, 15);
CREATE TABLE fragmentacion.inventario_zona4 PARTITION OF fragmentacion.inventario_frag
    FOR VALUES IN (16, 17, 18, 19, 20);
CREATE TABLE fragmentacion.inventario_otras PARTITION OF fragmentacion.inventario_frag
    DEFAULT;

-- ---------------------------------------------------------------------
-- 2. CARGA desde la tabla original (500 filas)
-- ---------------------------------------------------------------------
INSERT INTO fragmentacion.inventario_frag
       (id_inventario, id_sucursal, nombre, descripcion, estado)
SELECT id_inventario, id_sucursal, nombre, descripcion, estado
FROM public.inventario;

ANALYZE fragmentacion.inventario_frag;

-- El administrador (pg_dump) debe poder leer el esquema nuevo
GRANT USAGE ON SCHEMA fragmentacion TO rol_admin_pg;
GRANT SELECT ON ALL TABLES IN SCHEMA fragmentacion TO rol_admin_pg;

-- ---------------------------------------------------------------------
-- 3. VERIFICACION (una captura por bloque)
-- ---------------------------------------------------------------------

-- 3.1 Fragmentos y su criterio (5 filas)
SELECT c.relname AS fragmento,
       pg_get_expr(c.relpartbound, c.oid) AS criterio
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
WHERE i.inhparent = 'fragmentacion.inventario_frag'::regclass
ORDER BY c.relname;

-- 3.2 Filas por fragmento: 125 / 125 / 125 / 125 (otras no aparece: 0 filas)
SELECT tableoid::regclass AS fragmento, count(*) AS filas
FROM fragmentacion.inventario_frag
GROUP BY tableoid
ORDER BY 1;

-- 3.3 Sin perdida de filas: 500 = 500
SELECT (SELECT count(*) FROM public.inventario)               AS original,
       (SELECT count(*) FROM fragmentacion.inventario_frag)   AS fragmentada;

-- 3.4 Poda de particiones (pruning): solo se lee el fragmento de la zona 1
EXPLAIN
SELECT * FROM fragmentacion.inventario_frag WHERE id_sucursal = 3;

-- 3.5 Sin la clave de fragmentacion se leen todos los fragmentos (Append)
EXPLAIN
SELECT * FROM fragmentacion.inventario_frag WHERE estado = 'ACTIVO';

-- 3.6 Consulta por sucursal con datos reales (25 inventarios en la sucursal 3)
SELECT id_sucursal, count(*) AS inventarios
FROM fragmentacion.inventario_frag
WHERE id_sucursal = 3
GROUP BY id_sucursal;

-- ---------------------------------------------------------------------
-- 4. LIMPIEZA (solo si hay que repetir el script desde cero)
-- ---------------------------------------------------------------------
-- DROP SCHEMA fragmentacion CASCADE;
