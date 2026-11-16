-- =====================================================================
-- MypeInventario - ORACLE
-- Administracion de usuarios, roles y permisos
-- Ejecutar como SYS o SYSTEM dentro del PDB del proyecto:
--   sqlplus system@localhost:1521/FREEPDB1 @"5. Usuario.sql"
-- Las contrasenas NO estan en este archivo: SQL*Plus las solicita con
-- ACCEPT ... HIDE (entrada oculta).
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE
SET VERIFY OFF
SET SERVEROUTPUT ON

-- 1. PDB (descomentar si se usa CDB/PDB)
-- ALTER SESSION SET CONTAINER = FREEPDB1;

-- 2. ESQUEMA PROPIETARIO UNICO de las 20 tablas (EN MAYUSCULAS)
DEFINE v_owner = 'MYPE_INVENTARIO'

-- Verifica que el esquema exista y tenga las 20 tablas antes de otorgar permisos
DECLARE
  v_tablas NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_tablas FROM dba_tables WHERE owner = UPPER('&v_owner');
  IF v_tablas <> 20 THEN
    RAISE_APPLICATION_ERROR(-20001,
      'El esquema &v_owner tiene ' || v_tablas || ' tablas; se esperaban 20.');
  END IF;
END;
/

-- 3. CONTRASENAS (entrada oculta)
ACCEPT p_damian CHAR PROMPT 'Contrasena para ericson_damian: ' HIDE
ACCEPT p_pedro  CHAR PROMPT 'Contrasena para pedro_zavaleta: ' HIDE
ACCEPT p_jose   CHAR PROMPT 'Contrasena para jose_callupe:   ' HIDE
ACCEPT p_keyden CHAR PROMPT 'Contrasena para keyden_navarro: ' HIDE
ACCEPT p_yemima CHAR PROMPT 'Contrasena para yemima_reyes:   ' HIDE

-- 4. PERFIL DE SEGURIDAD
CREATE PROFILE PERFIL_MYPE LIMIT
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LIFE_TIME 90
  PASSWORD_LOCK_TIME 1;

-- 5. ROLES
CREATE ROLE ADMIN_ORACLE;
CREATE ROLE GESTOR_COMPRAS_ORACLE;
CREATE ROLE GESTOR_VENTAS_ORACLE;
CREATE ROLE ANALISTA_ORACLE;
CREATE ROLE CONSULTA_ORACLE;

-- 6. ADMIN_ORACLE: administra usuarios y roles; no tiene privilegios ANY
--    ni permisos de escritura sobre los datos.
GRANT CREATE SESSION, CREATE USER, ALTER USER, CREATE ROLE,
      CREATE PROFILE, ALTER PROFILE TO ADMIN_ORACLE;

-- La facultad de asignar los roles funcionales se otorga en la seccion 12,
-- directamente al usuario administrador y sin activarlos por defecto. Si se
-- otorgaran al rol ADMIN_ORACLE, este heredaria sus permisos de escritura.

-- Lectura del esquema para verificacion y exportacion
GRANT SELECT ON &v_owner..Comerciante       TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Negocio           TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Sucursal          TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Empleado          TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Proveedor         TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..CategoriaProducto TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Producto          TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..VarianteSKU       TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Compra            TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..DetalleCompra     TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Cliente           TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Venta             TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..DetalleVenta      TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..MetodoPago        TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..DireccionCliente  TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..Pedido            TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..DetallePedido     TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..CanalVenta        TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..VentaCanal        TO ADMIN_ORACLE;
GRANT SELECT ON &v_owner..PromocionComercial TO ADMIN_ORACLE;

-- 7. GESTOR_COMPRAS_ORACLE: compras y proveedores
GRANT CREATE SESSION TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON &v_owner..Proveedor     TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..Compra        TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..DetalleCompra TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT ON &v_owner..Negocio           TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT ON &v_owner..Sucursal          TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT ON &v_owner..CategoriaProducto TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT ON &v_owner..Producto          TO GESTOR_COMPRAS_ORACLE;
GRANT SELECT ON &v_owner..VarianteSKU       TO GESTOR_COMPRAS_ORACLE;

-- 8. GESTOR_VENTAS_ORACLE: ventas, pedidos, clientes y catalogo
GRANT CREATE SESSION TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON &v_owner..Cliente          TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON &v_owner..DireccionCliente TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..Venta            TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..DetalleVenta     TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..MetodoPago       TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..Pedido           TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..DetallePedido    TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..VentaCanal       TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..CategoriaProducto TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..Producto         TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..VarianteSKU      TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..CanalVenta       TO GESTOR_VENTAS_ORACLE;
GRANT SELECT, INSERT, UPDATE         ON &v_owner..PromocionComercial TO GESTOR_VENTAS_ORACLE;
GRANT SELECT ON &v_owner..Negocio  TO GESTOR_VENTAS_ORACLE;
GRANT SELECT ON &v_owner..Sucursal TO GESTOR_VENTAS_ORACLE;
GRANT SELECT ON &v_owner..Empleado TO GESTOR_VENTAS_ORACLE;

-- 9. ANALISTA_ORACLE: analisis financiero, solo lectura, sin datos personales
GRANT CREATE SESSION TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..Venta              TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..DetalleVenta       TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..MetodoPago         TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..Compra             TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..DetalleCompra      TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..Pedido             TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..DetallePedido      TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..Producto           TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..VarianteSKU        TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..CategoriaProducto  TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..Proveedor          TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..CanalVenta         TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..VentaCanal         TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..PromocionComercial TO ANALISTA_ORACLE;
GRANT SELECT ON &v_owner..Sucursal           TO ANALISTA_ORACLE;

-- 10. CONSULTA_ORACLE: auditoria, solo lectura sobre las 20 tablas
GRANT CREATE SESSION TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Comerciante        TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Negocio            TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Sucursal           TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Empleado           TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Proveedor          TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..CategoriaProducto  TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Producto           TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..VarianteSKU        TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Compra             TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..DetalleCompra      TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Cliente            TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Venta              TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..DetalleVenta       TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..MetodoPago         TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..DireccionCliente   TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..Pedido             TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..DetallePedido      TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..CanalVenta         TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..VentaCanal         TO CONSULTA_ORACLE;
GRANT SELECT ON &v_owner..PromocionComercial TO CONSULTA_ORACLE;

-- 11. USUARIOS (la contrasena debe cambiarse en el primer ingreso)
CREATE USER ericson_damian IDENTIFIED BY "&p_damian" DEFAULT TABLESPACE USERS PROFILE PERFIL_MYPE PASSWORD EXPIRE;
CREATE USER pedro_zavaleta IDENTIFIED BY "&p_pedro"  DEFAULT TABLESPACE USERS PROFILE PERFIL_MYPE PASSWORD EXPIRE;
CREATE USER jose_callupe   IDENTIFIED BY "&p_jose"   DEFAULT TABLESPACE USERS PROFILE PERFIL_MYPE PASSWORD EXPIRE;
CREATE USER keyden_navarro IDENTIFIED BY "&p_keyden" DEFAULT TABLESPACE USERS PROFILE PERFIL_MYPE PASSWORD EXPIRE;
CREATE USER yemima_reyes   IDENTIFIED BY "&p_yemima" DEFAULT TABLESPACE USERS PROFILE PERFIL_MYPE PASSWORD EXPIRE;

-- 12. ASIGNACION DE ROLES SEGUN EL PERFIL EN EL PROYECTO
GRANT ADMIN_ORACLE          TO ericson_damian;  -- Damian Garay, Ericson Anthony (DBA)
GRANT GESTOR_COMPRAS_ORACLE TO pedro_zavaleta;  -- Zavaleta Timana, Pedro Sebastian (Compras y Proveedores)
GRANT GESTOR_VENTAS_ORACLE  TO jose_callupe;    -- Callupe Torres, Jose Marcelo (Ventas e Inventario)
GRANT ANALISTA_ORACLE       TO keyden_navarro;  -- Navarro Caysahuana, Keyden Andrew (Analista Financiero)
GRANT CONSULTA_ORACLE       TO yemima_reyes;    -- Reyes Anticona, Yemima Milagros (Auditoria y Reportes)

-- El administrador puede asignar los roles funcionales a otros usuarios
-- (WITH ADMIN OPTION), pero no los tiene activos: su unico rol por defecto
-- es ADMIN_ORACLE, por lo que al conectarse no puede escribir en los datos.
GRANT GESTOR_COMPRAS_ORACLE, GESTOR_VENTAS_ORACLE, ANALISTA_ORACLE, CONSULTA_ORACLE
  TO ericson_damian WITH ADMIN OPTION;
ALTER USER ericson_damian DEFAULT ROLE ADMIN_ORACLE;

-- 13. VERIFICACION (para capturas del informe)
COLUMN grantee FORMAT A24
COLUMN privilege FORMAT A30
COLUMN granted_role FORMAT A26
COLUMN role FORMAT A26

-- Roles creados
SELECT role FROM dba_roles
WHERE role IN ('ADMIN_ORACLE','GESTOR_COMPRAS_ORACLE','GESTOR_VENTAS_ORACLE','ANALISTA_ORACLE','CONSULTA_ORACLE')
ORDER BY role;

-- Roles asignados a cada usuario
-- (ADMIN_OPTION = YES: puede asignarlo; DEFAULT_ROLE = NO: no lo tiene activo al conectarse)
SELECT grantee, granted_role, admin_option, default_role
FROM dba_role_privs
WHERE grantee IN ('ERICSON_DAMIAN','PEDRO_ZAVALETA','JOSE_CALLUPE','KEYDEN_NAVARRO','YEMIMA_REYES')
ORDER BY grantee, granted_role;

-- Privilegios de sistema por rol (no debe aparecer ningun privilegio ANY)
SELECT grantee, privilege
FROM dba_sys_privs
WHERE grantee IN ('ADMIN_ORACLE','GESTOR_COMPRAS_ORACLE','GESTOR_VENTAS_ORACLE','ANALISTA_ORACLE','CONSULTA_ORACLE')
ORDER BY grantee, privilege;

-- Privilegios sobre tablas por rol
SELECT grantee, COUNT(DISTINCT table_name) AS tablas,
       LISTAGG(DISTINCT privilege, ', ') WITHIN GROUP (ORDER BY privilege) AS privilegios
FROM dba_tab_privs
WHERE owner = UPPER('&v_owner')
  AND grantee IN ('ADMIN_ORACLE','GESTOR_COMPRAS_ORACLE','GESTOR_VENTAS_ORACLE','ANALISTA_ORACLE','CONSULTA_ORACLE')
GROUP BY grantee
ORDER BY grantee;
