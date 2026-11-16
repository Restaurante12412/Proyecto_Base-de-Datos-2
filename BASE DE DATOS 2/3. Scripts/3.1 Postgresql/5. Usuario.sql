-- =====================================================================
-- MypeInventario - PostgreSQL
-- Administracion de usuarios, roles y permisos
-- Ejecutar como superusuario (postgres) con psql, conectado a la base
-- "MypeInventario" (nombre entre comillas, igual que en CREATE DATABASE):
--   psql -U postgres -d "MypeInventario" -f "5. Usuario.sql"
-- Las contrasenas NO estan en este archivo: psql las solicita con
-- \password (entrada oculta) al final de la seccion 2.
-- =====================================================================
\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------
-- 1. ROLES FUNCIONALES (sin login, agrupan los permisos)
-- ---------------------------------------------------------------------
CREATE ROLE rol_admin_pg           NOLOGIN;
CREATE ROLE rol_gestor_inventario  NOLOGIN;
CREATE ROLE rol_gestor_operaciones NOLOGIN;
CREATE ROLE rol_analista_reportes  NOLOGIN;
CREATE ROLE rol_auditoria          NOLOGIN;

-- ---------------------------------------------------------------------
-- 2. USUARIOS (con login, sin privilegios de superusuario)
--    Solo el administrador tiene CREATEROLE.
-- ---------------------------------------------------------------------
CREATE ROLE ericson_damian LOGIN NOSUPERUSER NOCREATEDB CREATEROLE;
CREATE ROLE pedro_zavaleta LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE jose_callupe   LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE keyden_navarro LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE yemima_reyes   LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Contrasenas: se piden por consola (no quedan en el script ni en el historial)
\password ericson_damian
\password pedro_zavaleta
\password jose_callupe
\password keyden_navarro
\password yemima_reyes

-- ---------------------------------------------------------------------
-- 3. ACCESO A LA BASE DE DATOS Y AL ESQUEMA
-- ---------------------------------------------------------------------
REVOKE ALL ON DATABASE "MypeInventario" FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

GRANT CONNECT ON DATABASE "MypeInventario"
  TO rol_admin_pg, rol_gestor_inventario, rol_gestor_operaciones,
     rol_analista_reportes, rol_auditoria;

GRANT USAGE ON SCHEMA public
  TO rol_admin_pg, rol_gestor_inventario, rol_gestor_operaciones,
     rol_analista_reportes, rol_auditoria;

-- ---------------------------------------------------------------------
-- 4. ADMINISTRADOR (DBA): rol_admin_pg
--    Administra usuarios y roles; sobre los datos solo lee (SELECT),
--    lo necesario para verificar y para ejecutar pg_dump.
--    Sin ALL PRIVILEGES, sin GRANT OPTION, sin CREATE en base ni esquema.
-- ---------------------------------------------------------------------
GRANT SELECT ON
  public.inventario, public.almacen, public.ubicacionproducto, public.stock,
  public.movimientoinventario, public.tipomovimiento, public.codigobarras,
  public.alertareabastecimiento, public.configuracionreabastecimiento,
  public.devolucion, public.detalledevolucion, public.promocion,
  public.productopromocion, public.historialstock,
  public.transferenciainventario, public.detalletransferencia,
  public.conteoinventario, public.detalleconteoinventario,
  public.loteproducto, public.detallelote
TO rol_admin_pg;

-- Lectura de las secuencias de las columnas IDENTITY (pg_dump la necesita)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_admin_pg;

-- Permite al administrador asignar los roles funcionales a otros usuarios.
-- INHERIT FALSE y SET FALSE (PostgreSQL 16+): el administrador puede otorgar
-- estos roles, pero no hereda ni asume sus permisos de escritura.
GRANT rol_gestor_inventario  TO rol_admin_pg WITH ADMIN OPTION, INHERIT FALSE, SET FALSE;
GRANT rol_gestor_operaciones TO rol_admin_pg WITH ADMIN OPTION, INHERIT FALSE, SET FALSE;
GRANT rol_analista_reportes  TO rol_admin_pg WITH ADMIN OPTION, INHERIT FALSE, SET FALSE;
GRANT rol_auditoria          TO rol_admin_pg WITH ADMIN OPTION, INHERIT FALSE, SET FALSE;

-- ---------------------------------------------------------------------
-- 5. GESTOR DE INVENTARIO Y ALMACEN: rol_gestor_inventario
--    Movimientos e historial: solo SELECT e INSERT (trazabilidad).
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.inventario, public.almacen, public.ubicacionproducto, public.stock,
  public.tipomovimiento, public.codigobarras,
  public.configuracionreabastecimiento, public.alertareabastecimiento,
  public.transferenciainventario, public.detalletransferencia,
  public.conteoinventario, public.detalleconteoinventario,
  public.loteproducto, public.detallelote
TO rol_gestor_inventario;

GRANT SELECT, INSERT ON
  public.movimientoinventario, public.historialstock
TO rol_gestor_inventario;

GRANT SELECT ON
  public.devolucion, public.detalledevolucion,
  public.promocion, public.productopromocion
TO rol_gestor_inventario;

-- ---------------------------------------------------------------------
-- 6. GESTOR DE OPERACIONES Y DEVOLUCIONES: rol_gestor_operaciones
--    Stock y alertas: sin DELETE. Movimientos: solo SELECT e INSERT.
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.devolucion, public.detalledevolucion, public.promocion,
  public.productopromocion, public.transferenciainventario,
  public.detalletransferencia, public.conteoinventario,
  public.detalleconteoinventario
TO rol_gestor_operaciones;

GRANT SELECT, INSERT, UPDATE ON
  public.stock, public.alertareabastecimiento
TO rol_gestor_operaciones;

GRANT SELECT, INSERT ON
  public.movimientoinventario
TO rol_gestor_operaciones;

GRANT SELECT ON
  public.inventario, public.almacen, public.ubicacionproducto,
  public.tipomovimiento, public.codigobarras,
  public.configuracionreabastecimiento, public.historialstock,
  public.loteproducto, public.detallelote
TO rol_gestor_operaciones;

-- ---------------------------------------------------------------------
-- 7. ANALISTA DE INVENTARIO Y REPORTES: rol_analista_reportes (solo lectura)
-- ---------------------------------------------------------------------
GRANT SELECT ON
  public.inventario, public.almacen, public.ubicacionproducto, public.stock,
  public.movimientoinventario, public.tipomovimiento,
  public.alertareabastecimiento, public.devolucion,
  public.detalledevolucion, public.promocion, public.productopromocion,
  public.historialstock, public.transferenciainventario,
  public.detalletransferencia, public.conteoinventario,
  public.detalleconteoinventario, public.loteproducto, public.detallelote
TO rol_analista_reportes;

-- ---------------------------------------------------------------------
-- 8. AUDITORIA - SOLO LECTURA: rol_auditoria (las 20 tablas)
-- ---------------------------------------------------------------------
GRANT SELECT ON
  public.inventario, public.almacen, public.ubicacionproducto, public.stock,
  public.movimientoinventario, public.tipomovimiento, public.codigobarras,
  public.alertareabastecimiento, public.configuracionreabastecimiento,
  public.devolucion, public.detalledevolucion, public.promocion,
  public.productopromocion, public.historialstock,
  public.transferenciainventario, public.detalletransferencia,
  public.conteoinventario, public.detalleconteoinventario,
  public.loteproducto, public.detallelote
TO rol_auditoria;

-- ---------------------------------------------------------------------
-- 9. ASIGNACION DE ROLES A USUARIOS
-- ---------------------------------------------------------------------
GRANT rol_admin_pg           TO ericson_damian;
GRANT rol_gestor_inventario  TO pedro_zavaleta;
GRANT rol_gestor_operaciones TO jose_callupe;
GRANT rol_analista_reportes  TO keyden_navarro;
GRANT rol_auditoria          TO yemima_reyes;

-- ---------------------------------------------------------------------
-- 10. VERIFICACION
-- ---------------------------------------------------------------------

-- Atributos de usuarios y roles (rolsuper debe ser false en todos)
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_roles
WHERE rolname IN ('rol_admin_pg', 'rol_gestor_inventario', 'rol_gestor_operaciones',
                  'rol_analista_reportes', 'rol_auditoria', 'ericson_damian',
                  'pedro_zavaleta', 'jose_callupe', 'keyden_navarro', 'yemima_reyes')
ORDER BY rolcanlogin, rolname;

-- Roles asignados a cada usuario
SELECT m.rolname AS usuario, r.rolname AS rol, am.admin_option
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
WHERE m.rolname IN ('ericson_damian', 'pedro_zavaleta', 'jose_callupe',
                    'keyden_navarro', 'yemima_reyes')
ORDER BY m.rolname;

-- Permisos por tabla de cada rol
SELECT grantee AS rol,
       table_name AS tabla,
       string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('rol_admin_pg', 'rol_gestor_inventario', 'rol_gestor_operaciones',
                  'rol_analista_reportes', 'rol_auditoria')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- Resumen de permisos por rol
SELECT grantee AS rol,
       count(DISTINCT table_name) AS tablas,
       string_agg(DISTINCT privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('rol_admin_pg', 'rol_gestor_inventario', 'rol_gestor_operaciones',
                  'rol_analista_reportes', 'rol_auditoria')
GROUP BY grantee
ORDER BY grantee;
