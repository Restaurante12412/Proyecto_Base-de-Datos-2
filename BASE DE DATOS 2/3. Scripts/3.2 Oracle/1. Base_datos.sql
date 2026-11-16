-- =====================================================================
-- MypeInventario - ORACLE
-- 1. Base de datos (esquema propietario MYPE_INVENTARIO)
-- En Oracle no se crea una base por proyecto: se crea un esquema (usuario)
-- propietario de las 20 tablas dentro del PDB.
-- Ejecutar como SYSTEM dentro del PDB del proyecto:
--   sqlplus system@localhost:1521/FREEPDB1 @"1. Base_datos.sql"
-- La contrasena NO esta en este archivo: se solicita con ACCEPT ... HIDE
-- (entrada oculta).
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE
SET VERIFY OFF

-- 1. CONTRASENA DEL ESQUEMA (entrada oculta)
ACCEPT p_owner CHAR PROMPT 'Contrasena para MYPE_INVENTARIO: ' HIDE

-- 2. ESQUEMA PROPIETARIO
CREATE USER MYPE_INVENTARIO IDENTIFIED BY "&p_owner"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- 3. PRIVILEGIOS MINIMOS para crear sus propios objetos
--    (sin DBA, sin RESOURCE, sin privilegios ANY)
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE
  TO MYPE_INVENTARIO;

-- 4. VERIFICACION
COLUMN username FORMAT A20
COLUMN account_status FORMAT A16
COLUMN default_tablespace FORMAT A20
COLUMN privilege FORMAT A24

SELECT username, account_status, default_tablespace
FROM dba_users
WHERE username = 'MYPE_INVENTARIO';

SELECT privilege
FROM dba_sys_privs
WHERE grantee = 'MYPE_INVENTARIO'
ORDER BY privilege;
