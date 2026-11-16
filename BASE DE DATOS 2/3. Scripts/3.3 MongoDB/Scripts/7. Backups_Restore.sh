#!/bin/bash
# =====================================================================
# MypeInventario - MongoDB
# 7. Backups_Restore.sh  -  Respaldo y restauracion con mongodump / mongorestore
#
# ESTRATEGIA
#   Tipo       : logico, base completa mype_inventario (5 colecciones, sus
#                indices y validadores), en un solo archivo comprimido.
#   Usuario    : admin_mype (administrador de la instancia).
#   Frecuencia : diario, y uno adicional antes de cada entrega.
#   Retencion  : 7 dias; se eliminan los archivos mas antiguos (paso 8).
#   Ubicacion  : volumen Docker mype_mongo_backups (/backups dentro de
#                mype-mongo1) + copia en "4. Backups/MongoDB" del repositorio.
#   Validacion : cada backup se restaura en la base de pruebas
#                mype_inventario_restore y se comparan colecciones,
#                documentos e indices (paso 5).
#
# Contenedores: replica set rsMype (mype-mongo1..3). Ejecutar en WSL desde
# la carpeta "3.3 MongoDB/Scripts", paso a paso, capturando cada salida.
# =====================================================================
FECHA=20261115          # cambiar la fecha en cada backup nuevo
DEST="../../../4. Backups/MongoDB"   # carpeta del repositorio donde se copian

# La clave del administrador se pide una sola vez, con entrada oculta; no queda en el archivo.
read -s -p "Contrasena de admin_mype: " MONGO_PW; echo

URI="mongodb://mype-mongo1:27017,mype-mongo2:27017,mype-mongo3:27017/?replicaSet=rsMype"
AUT="-u admin_mype -p $MONGO_PW --authenticationDatabase admin"
CONTEO="['mype_inventario','mype_inventario_restore'].forEach(function (b) { var d = db.getSiblingDB(b); d.getCollectionNames().sort().forEach(function (c) { print(b + '.' + c + ': ' + d.getCollection(c).countDocuments({})); }); })"

# ---------- 1. Conteos ANTES del backup (referencia) ----------
docker exec mype-mongo1 mongosh "$URI" $AUT --quiet --eval "$CONTEO"
# Esperado: 500 documentos en cada una de las 5 colecciones de mype_inventario

# ---------- 2. Backup ----------
docker exec mype-mongo1 bash -c "mongodump --uri='$URI' $AUT --db=mype_inventario --gzip --archive=/backups/mype_mongo_$FECHA.gz 2> /backups/mype_mongo_export_$FECHA.log"

# ---------- 3. Comprobar que existe ----------
docker exec mype-mongo1 ls -lh /backups
docker exec mype-mongo1 tail -n 8 /backups/mype_mongo_export_$FECHA.log     # "done dumping ..." por coleccion

# ---------- 4. Restauracion de prueba en otra base ----------
docker exec mype-mongo1 bash -c "mongorestore --uri='$URI' $AUT --gzip --archive=/backups/mype_mongo_$FECHA.gz --nsFrom='mype_inventario.*' --nsTo='mype_inventario_restore.*' 2> /backups/mype_mongo_import_$FECHA.log"
docker exec mype-mongo1 tail -n 5 /backups/mype_mongo_import_$FECHA.log     # "2500 document(s) restored successfully. 0 document(s) failed"

# ---------- 5. Verificar: la base restaurada debe ser igual a la original ----------
docker exec mype-mongo1 mongosh "$URI" $AUT --quiet --eval "$CONTEO"
# Comparacion con indices, coleccion por coleccion (pide la contrasena):
bash "0. Ejecutar.sh" "7. Backups_Restore.js"

# ---------- 6. Copiar los archivos a la carpeta del repositorio ----------
mkdir -p "$DEST"
docker cp mype-mongo1:/backups/mype_mongo_$FECHA.gz "$DEST/"
docker cp mype-mongo1:/backups/mype_mongo_export_$FECHA.log "$DEST/"
docker cp mype-mongo1:/backups/mype_mongo_import_$FECHA.log "$DEST/"
ls -lh "$DEST"

# ---------- 7. (Opcional) Restaurar sobre la base original ----------
# Solo si hiciera falta recuperar datos en mype_inventario. --drop borra cada coleccion antes de restaurarla:
#   docker exec mype-mongo1 bash -c "mongorestore --uri='$URI' $AUT --gzip --archive=/backups/mype_mongo_$FECHA.gz --drop"

# ---------- 8. Retencion y limpieza ----------
# Elimina backups y logs con mas de 7 dias:
#   docker exec mype-mongo1 find /backups -name 'mype_mongo_*' -mtime +7 -delete
# Elimina la base de pruebas despues de verificar:
#   docker exec mype-mongo1 mongosh "$URI" $AUT --quiet --eval "db.getSiblingDB('mype_inventario_restore').dropDatabase()"
