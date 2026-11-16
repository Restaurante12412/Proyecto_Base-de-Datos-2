#!/bin/bash
# ============================================================
# 1. Crear_ReplicaSet.sh  -  Crea el replica set MongoDB de MypeInventario
# Ejecutar en WSL:  bash "1. Crear_ReplicaSet.sh"
# Es el entorno de MongoDB del proyecto: despues se ejecutan los scripts
# de la carpeta "3.3 MongoDB/Scripts" (colecciones, datos, usuarios...).
#
# - Replica set rsMype con 3 nodos: mype-mongo1, mype-mongo2 y mype-mongo3.
#   Un nodo queda como PRIMARY (recibe las escrituras) y los otros dos como
#   SECONDARY: copian el registro de operaciones (oplog) del primario de
#   forma ASINCRONICA, es decir, el primario confirma la escritura sin
#   esperar a que los secundarios la hayan aplicado.
# - Imagen mongo:7.
# - Autenticacion activa: los nodos se autentican entre si con un keyfile
#   (obligatorio en un replica set con usuarios) y se crea el
#   administrador admin_mype. Su contrasena se pide con entrada oculta y
#   no se guarda en archivos.
# - Volumenes: mype_mongo_data1..3 (datos), mype_mongo_key (keyfile) y
#   mype_mongo_backups (/backups en mype-mongo1, para mongodump).
# - Puertos en el host: 27021, 27022 y 27023.
# ============================================================
RED=mype-mongo-net
IMAGEN=mongo:7
RS=rsMype

if docker ps -a --format '{{.Names}}' | grep -q '^mype-mongo[123]$'; then
  echo "Ya existen contenedores mype-mongo. Para empezar de cero:"
  echo "  docker rm -f mype-mongo1 mype-mongo2 mype-mongo3"
  echo "  docker volume rm mype_mongo_data1 mype_mongo_data2 mype_mongo_data3 mype_mongo_key mype_mongo_backups"
  exit 1
fi

read -s -p "Contrasena para el administrador admin_mype (solo letras y numeros): " P1; echo
read -s -p "Repetir contrasena: " P2; echo
if [ "$P1" != "$P2" ]; then echo "Las contrasenas no coinciden."; exit 1; fi

docker network create $RED > /dev/null 2>&1
docker volume create mype_mongo_key > /dev/null
docker volume create mype_mongo_backups > /dev/null

# Keyfile compartido por los 3 nodos (solo lo puede leer el usuario mongodb, uid 999)
docker run --rm -v mype_mongo_key:/key $IMAGEN bash -c \
  "head -c 756 /dev/urandom | base64 -w 0 > /key/keyfile && chmod 400 /key/keyfile && chown 999:999 /key/keyfile"

for i in 1 2 3; do
  docker volume create mype_mongo_data$i > /dev/null
  EXTRA=""
  if [ $i -eq 1 ]; then EXTRA="-v mype_mongo_backups:/backups"; fi
  docker run -d --name mype-mongo$i --network $RED -p 2702$i:27017 \
    -v mype_mongo_data$i:/data/db -v mype_mongo_key:/key $EXTRA \
    $IMAGEN mongod --replSet $RS --bind_ip_all --keyFile /key/keyfile > /dev/null
done

# Esperar a que los 3 nodos acepten conexiones
for i in 1 2 3; do
  for n in $(seq 1 30); do
    docker exec mype-mongo$i mongosh --quiet --eval "db.adminCommand('ping').ok" > /dev/null 2>&1 && break
    sleep 2
  done
done

# Iniciar el replica set (permitido sin usuario por la excepcion de localhost)
docker exec mype-mongo1 mongosh --quiet --eval "
  rs.initiate({ _id: '$RS', members: [
    { _id: 0, host: 'mype-mongo1:27017', priority: 2 },
    { _id: 1, host: 'mype-mongo2:27017', priority: 1 },
    { _id: 2, host: 'mype-mongo3:27017', priority: 1 } ] })"

# Esperar a que mype-mongo1 sea PRIMARY
for n in $(seq 1 30); do
  ES=$(docker exec mype-mongo1 mongosh --quiet --eval "db.hello().isWritablePrimary" 2>/dev/null)
  if [ "$ES" = "true" ]; then break; fi
  sleep 2
done

# Primer usuario: administrador de la instancia (excepcion de localhost)
docker exec mype-mongo1 mongosh --quiet --eval "
  db.getSiblingDB('admin').createUser({ user: 'admin_mype', pwd: '$P1', roles: [ { role: 'root', db: 'admin' } ] })"

# Evidencia: 1 PRIMARY y 2 SECONDARY
docker exec mype-mongo1 mongosh --quiet -u admin_mype -p "$P1" --authenticationDatabase admin --eval "
  rs.status().members.forEach(function (m) { print(m.name + '  ' + m.stateStr + '  salud=' + m.health); })"
docker ps --filter "name=mype-mongo"
