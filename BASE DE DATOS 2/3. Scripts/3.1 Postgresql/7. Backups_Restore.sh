#!/bin/bash
# =====================================================================
# MypeInventario - PostgreSQL
# 7. Backups_Restore.sh  -  Respaldo y restauracion con pg_dump / pg_restore
#
# ESTRATEGIA
#   Tipo       : logico, base completa "MypeInventario" (estructura + datos),
#                formato personalizado de pg_dump (-F c), comprimido.
#   Usuario    : ericson_damian (administrador, solo lectura sobre los datos).
#   Frecuencia : diario, y uno adicional antes de cada entrega.
#   Retencion  : 7 dias; se eliminan los archivos mas antiguos (paso 9).
#   Ubicacion  : volumen Docker mype_pg_backups (/backups dentro del contenedor)
#                + copia en la carpeta "4. Backups" del repositorio y en la nube.
#   Validacion : cada backup se restaura en la base de pruebas
#                "MypeInventario_restore" y se comparan tablas, claves foraneas,
#                registros, funciones e indices (paso 6).
#
# Contenedor: mype-postgres (postgres:16). Ejecutar en WSL, paso a paso,
# capturando la salida de cada paso.
# Las contrasenas no estan en este archivo: pg_dump las pide por consola.
# =====================================================================
FECHA=20261115          # cambiar la fecha en cada backup nuevo
DEST="../../4. Backups/PostgreSQL"   # carpeta del repositorio donde se copian (ejecutar desde "3.1 Postgresql")
mkdir -p "$DEST"
PG="docker exec mype-postgres"

# Consulta de verificacion: tablas, FK, registros por tabla, funciones e indices
VERIF="
SELECT '01_tablas' AS item, count(*)::text AS valor
FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'
UNION ALL
SELECT '02_claves_foraneas', count(*)::text
FROM information_schema.table_constraints WHERE table_schema='public' AND constraint_type='FOREIGN KEY'
UNION ALL
SELECT '03_funciones_y_procedimientos', count(*)::text
FROM pg_proc WHERE pronamespace='public'::regnamespace
UNION ALL
SELECT '04_indices_idx', count(*)::text
FROM pg_indexes WHERE schemaname='public' AND indexname LIKE 'idx%'
UNION ALL
SELECT '10_' || table_name::text,
       ((xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I.%I', table_schema, table_name), false, true, '')))[1])::text
FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'
ORDER BY 1;"

# ---------- 1. Conteos ANTES del backup (referencia) ----------
$PG psql -U postgres -d "MypeInventario" -At -F ' | ' -c "$VERIF" | tee /tmp/pg_antes_$FECHA.txt
# Esperado: 20 tablas / 17 FK / 5 funciones y procedimientos / 5 indices / 500 por tabla

# ---------- 2. Backup (pide la contrasena de ericson_damian) ----------
# Se conecta por la IP del contenedor (no por el socket local) para que se exija la contrasena.
# -it es necesario para que pg_dump pueda pedirla.
docker exec -it mype-postgres bash -c "pg_dump -h \$(hostname -i) -p 5432 -U ericson_damian -d MypeInventario -F c -v -f /backups/mype_pg_$FECHA.dump 2> /backups/mype_pg_export_$FECHA.log"

# ---------- 3. Comprobar que existe ----------
$PG ls -lh /backups
$PG tail -n 5 /backups/mype_pg_export_$FECHA.log          # termina sin "error"

# ---------- 4. Contenido del backup ----------
$PG pg_restore -l /backups/mype_pg_$FECHA.dump | head -40
$PG bash -c "pg_restore -l /backups/mype_pg_$FECHA.dump | grep -c 'TABLE DATA'"    # 20

# ---------- 5. Restauracion de prueba en una base aparte ----------
$PG createdb -U postgres "MypeInventario_restore"
$PG bash -c "pg_restore -U postgres -d MypeInventario_restore -v /backups/mype_pg_$FECHA.dump 2> /backups/mype_pg_import_$FECHA.log"
$PG tail -n 5 /backups/mype_pg_import_$FECHA.log
# Si el log muestra algun error aislado (por ejemplo por el esquema public), revisar con:
#   $PG grep -i error /backups/mype_pg_import_$FECHA.log

# ---------- 6. Verificar: la base restaurada debe ser igual a la original ----------
$PG psql -U postgres -d "MypeInventario_restore" -At -F ' | ' -c "$VERIF" | tee /tmp/pg_despues_$FECHA.txt
diff /tmp/pg_antes_$FECHA.txt /tmp/pg_despues_$FECHA.txt && echo "DIFERENCIA: NO (restauracion correcta)"

# ---------- 7. Copiar los archivos a la carpeta del repositorio ----------
docker cp mype-postgres:/backups/mype_pg_$FECHA.dump "$DEST/"
docker cp mype-postgres:/backups/mype_pg_export_$FECHA.log "$DEST/"
docker cp mype-postgres:/backups/mype_pg_import_$FECHA.log "$DEST/"
ls -lh "$DEST"/mype_pg_*

# ---------- 8. (Opcional) Restaurar sobre la base original ----------
# Solo si hiciera falta recuperar datos en "MypeInventario". --clean borra los objetos antes de crearlos:
#   $PG pg_restore -U postgres -d MypeInventario --clean --if-exists -v /backups/mype_pg_$FECHA.dump

# ---------- 9. Retencion y limpieza ----------
# Elimina backups y logs con mas de 7 dias:
#   $PG find /backups -name 'mype_pg_*' -mtime +7 -delete
# Elimina la base de pruebas despues de verificar:
#   $PG dropdb -U postgres "MypeInventario_restore"
