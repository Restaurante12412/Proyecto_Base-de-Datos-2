-- =====================================================================
-- MypeInventario - PostgreSQL
-- 7. Backups y Restore (pg_dump / pg_restore)
--
-- ESTRATEGIA
--   Tipo       : logico, base completa "MypeInventario" (estructura + datos),
--                formato personalizado de pg_dump (-F c), comprimido.
--   Usuario    : ericson_damian (administrador, solo lectura sobre los datos).
--   Frecuencia : diario, y uno adicional antes de cada entrega.
--   Retencion  : 7 dias; se eliminan los archivos mas antiguos.
--   Ubicacion  : volumen Docker mype_pg_backups (/backups dentro del contenedor
--                mype-postgres) + copia en la carpeta "4. Backups/PostgreSQL"
--                del repositorio y en la nube.
--   Validacion : cada backup se restaura en la base de pruebas
--                "MypeInventario_restore" y se comparan tablas, claves
--                foraneas, registros, funciones e indices.
--
-- Este archivo tiene dos partes:
--   A. Los comandos de respaldo y restauracion, como referencia. Son
--      comandos de consola; el script que los ejecuta paso a paso en el
--      contenedor es "7. Backups_Restore.sh".
--   B. La consulta de verificacion (SQL), que se ejecuta con psql o
--      pgAdmin en "MypeInventario" y en "MypeInventario_restore".
--
-- Las contrasenas NO estan en este archivo: pg_dump las pide por consola.
-- Reemplazar YYYYMMDD por la fecha del backup (ejemplo: 20261115).
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. COMANDOS (consola WSL; ver "7. Backups_Restore.sh")
-- ---------------------------------------------------------------------
/*
-- 1. Backup (pide la contrasena de ericson_damian)
docker exec -it mype-postgres bash -c "pg_dump -h \$(hostname -i) -p 5432 -U ericson_damian -d MypeInventario -F c -v -f /backups/mype_pg_YYYYMMDD.dump 2> /backups/mype_pg_export_YYYYMMDD.log"

-- 2. Contenido del backup
docker exec mype-postgres pg_restore -l /backups/mype_pg_YYYYMMDD.dump

-- 3. Restauracion de prueba en una base aparte
docker exec mype-postgres createdb -U postgres "MypeInventario_restore"
docker exec mype-postgres bash -c "pg_restore -U postgres -d MypeInventario_restore -v /backups/mype_pg_YYYYMMDD.dump 2> /backups/mype_pg_import_YYYYMMDD.log"

-- 4. Copia al repositorio (desde la carpeta "3.1 Postgresql")
docker cp mype-postgres:/backups/mype_pg_YYYYMMDD.dump "../../4. Backups/PostgreSQL/"

-- 5. Retencion (7 dias) y limpieza de la base de pruebas
docker exec mype-postgres find /backups -name 'mype_pg_*' -mtime +7 -delete
docker exec mype-postgres dropdb -U postgres "MypeInventario_restore"
*/


-- ---------------------------------------------------------------------
-- B. VERIFICACION (SQL)
--    Ejecutar en "MypeInventario" y en "MypeInventario_restore"; los
--    resultados deben ser iguales.
--    Esperado: 20 tablas / 17 claves foraneas / 5 funciones y
--    procedimientos / 5 indices idx_ / 500 registros por tabla.
-- ---------------------------------------------------------------------

-- Base en la que se esta ejecutando
SELECT current_database() AS base_de_datos;

-- Objetos del esquema public
SELECT '01_tablas' AS item, count(*)::text AS valor
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT '02_claves_foraneas', count(*)::text
FROM information_schema.table_constraints
WHERE table_schema = 'public' AND constraint_type = 'FOREIGN KEY'
UNION ALL
SELECT '03_funciones_y_procedimientos', count(*)::text
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
UNION ALL
SELECT '04_indices_idx', count(*)::text
FROM pg_indexes
WHERE schemaname = 'public' AND indexname LIKE 'idx%'
ORDER BY 1;

-- Registros por tabla
SELECT table_name AS tabla,
       (xpath('/row/c/text()',
              query_to_xml(format('SELECT count(*) AS c FROM %I.%I',
                                  table_schema, table_name),
                           false, true, '')))[1]::text::bigint AS registros
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;
