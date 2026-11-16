-- =====================================================================
-- MypeInventario - ORACLE
-- 7. Backups y Restore (Data Pump: expdp / impdp)
--
-- ESTRATEGIA
--   Tipo       : logico, con Oracle Data Pump, a nivel de esquema
--                (MYPE_INVENTARIO: 20 tablas, restricciones y datos).
--   Frecuencia : semanal durante el desarrollo, y uno adicional antes de
--                cada entrega.
--   Retencion  : ultimos 3 backups; se elimina el mas antiguo al generar
--                uno nuevo.
--   Ubicacion  : C:\oracle_backups\mype_inventario\  + copia en la nube
--                (Drive/OneDrive) y en la carpeta "4. Backups" del repositorio.
--   Validacion : cada backup se restaura en el esquema de pruebas
--                MYPE_INVENTARIO_TEST y se comparan tablas y registros.
--
-- Las contrasenas NO estan en este archivo: expdp e impdp las solicitan
-- por consola (entrada oculta) porque el usuario se escribe sin contrasena.
--
-- Los pasos 1, 3, 5 y 6 son SQL (ejecutar como SYSTEM en el PDB FREEPDB1).
-- Los pasos 2 y 4 son comandos de consola (CMD de Windows); estan dentro
-- de comentarios para que este archivo pueda abrirse como .sql.
-- Reemplazar YYYYMMDD por la fecha del backup (ejemplo: 20261110).
-- La carpeta C:\oracle_backups\mype_inventario debe existir antes del paso 1.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. DIRECTORIO DE RESPALDOS (SQL, como SYSTEM)
-- ---------------------------------------------------------------------
CREATE OR REPLACE DIRECTORY MYPE_BACKUP_DIR AS 'C:\oracle_backups\mype_inventario';

-- Verifica el directorio
SELECT directory_name, directory_path
FROM dba_directories
WHERE directory_name = 'MYPE_BACKUP_DIR';


-- ---------------------------------------------------------------------
-- 2. BACKUP (CMD) - exporta el esquema MYPE_INVENTARIO
--    Genera el archivo .dmp y el log de exportacion en el directorio.
-- ---------------------------------------------------------------------
/*
expdp SYSTEM@localhost:1521/FREEPDB1 DIRECTORY=MYPE_BACKUP_DIR DUMPFILE=mype_backup_YYYYMMDD.dmp LOGFILE=mype_export_YYYYMMDD.log SCHEMAS=MYPE_INVENTARIO
*/


-- ---------------------------------------------------------------------
-- 3. CONTEO ANTES DE RESTAURAR (SQL) - esquema original
-- ---------------------------------------------------------------------
SELECT owner, COUNT(*) AS tablas
FROM dba_tables
WHERE owner = 'MYPE_INVENTARIO'
GROUP BY owner;


-- ---------------------------------------------------------------------
-- 4. RESTAURACION DE PRUEBA (CMD)
--    Se restaura en el esquema MYPE_INVENTARIO_TEST para no tocar el
--    esquema original. impdp crea el esquema de pruebas.
-- ---------------------------------------------------------------------
/*
impdp SYSTEM@localhost:1521/FREEPDB1 DIRECTORY=MYPE_BACKUP_DIR DUMPFILE=mype_backup_YYYYMMDD.dmp LOGFILE=mype_import_YYYYMMDD.log REMAP_SCHEMA=MYPE_INVENTARIO:MYPE_INVENTARIO_TEST
*/


-- ---------------------------------------------------------------------
-- 5. VERIFICACION (SQL, como SYSTEM)
--    Los dos esquemas deben tener las mismas tablas y los mismos registros.
-- ---------------------------------------------------------------------
COLUMN owner FORMAT A24
COLUMN table_name FORMAT A24

-- Numero de tablas por esquema (deben ser 20 en ambos)
SELECT owner, COUNT(*) AS tablas
FROM dba_tables
WHERE owner IN ('MYPE_INVENTARIO', 'MYPE_INVENTARIO_TEST')
GROUP BY owner
ORDER BY owner;

-- Numero de claves foraneas por esquema (deben ser 27 en ambos)
SELECT owner, COUNT(*) AS claves_foraneas
FROM dba_constraints
WHERE owner IN ('MYPE_INVENTARIO', 'MYPE_INVENTARIO_TEST')
  AND constraint_type = 'R'
GROUP BY owner
ORDER BY owner;

-- Registros por tabla en cada esquema
SELECT table_name, owner,
       TO_NUMBER(EXTRACTVALUE(
         XMLTYPE(DBMS_XMLGEN.GETXML(
           'SELECT COUNT(*) AS c FROM "' || owner || '"."' || table_name || '"')),
         '/ROWSET/ROW/C')) AS registros
FROM dba_tables
WHERE owner IN ('MYPE_INVENTARIO', 'MYPE_INVENTARIO_TEST')
ORDER BY table_name, owner;


-- ---------------------------------------------------------------------
-- 6. LIMPIEZA (SQL, como SYSTEM) - despues de verificar
--    Descomentar para eliminar el esquema de pruebas.
-- ---------------------------------------------------------------------
-- DROP USER MYPE_INVENTARIO_TEST CASCADE;
