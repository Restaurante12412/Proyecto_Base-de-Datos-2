#!/bin/bash
# ============================================================
# 1. Crear_Cluster_Shards.sh  -  Cluster fragmentado (sharding) de MongoDB
# Ejecutar en WSL:  bash "1. Crear_Cluster_Shards.sh"
#
# En MongoDB la fragmentacion horizontal se llama sharding: los
# documentos de una coleccion se reparten entre varios servidores
# (shards) segun el valor de una clave de fragmentacion.
#
# Es un entorno APARTE del replica set del proyecto (mype-mongo1..3): solo
# sirve para demostrar la fragmentacion y se puede apagar despues de
# tomar las capturas. Para no cargar la laptop usa el minimo de piezas:
#   mype-cfg1     servidor de configuracion (guarda que rango va a que shard)
#   mype-shard1   shard 1 (fragmento 1)
#   mype-shard2   shard 2 (fragmento 2)
#   mype-mongos   enrutador: recibe las consultas y las envia al shard correcto
# En produccion cada pieza seria un replica set de 3 nodos.
# Sin autenticacion: es un entorno de demostracion sin usuarios.
# Puerto en el host: 27030 (mongos).
#
# Al terminar este script, ejecutar "2. Fragmentacion.sh".
# ============================================================
RED=mype-shard-net
IMAGEN=mongo:7

if docker ps -a --format '{{.Names}}' | grep -q '^mype-\(cfg1\|shard1\|shard2\|mongos\)$'; then
  echo "Ya existen contenedores del cluster. Para empezar de cero:"
  echo "  docker rm -f mype-mongos mype-shard1 mype-shard2 mype-cfg1"
  exit 1
fi

esperar() {   # espera a que el contenedor $1 acepte conexiones
  for n in $(seq 1 40); do
    docker exec $1 mongosh --quiet --eval "db.adminCommand('ping').ok" > /dev/null 2>&1 && return 0
    sleep 2
  done
  echo "El contenedor $1 no respondio. Revisar: docker logs $1"; exit 1
}

docker network create $RED > /dev/null 2>&1

# Servidor de configuracion y los dos shards (cada uno es un replica set de 1 nodo)
docker run -d --name mype-cfg1   --network $RED $IMAGEN mongod --configsvr --replSet rsCfg    --port 27017 --bind_ip_all > /dev/null
docker run -d --name mype-shard1 --network $RED $IMAGEN mongod --shardsvr  --replSet rsShard1 --port 27017 --bind_ip_all > /dev/null
docker run -d --name mype-shard2 --network $RED $IMAGEN mongod --shardsvr  --replSet rsShard2 --port 27017 --bind_ip_all > /dev/null
esperar mype-cfg1; esperar mype-shard1; esperar mype-shard2

docker exec mype-cfg1   mongosh --quiet --eval "rs.initiate({ _id: 'rsCfg', configsvr: true, members: [{ _id: 0, host: 'mype-cfg1:27017' }] })"
docker exec mype-shard1 mongosh --quiet --eval "rs.initiate({ _id: 'rsShard1', members: [{ _id: 0, host: 'mype-shard1:27017' }] })"
docker exec mype-shard2 mongosh --quiet --eval "rs.initiate({ _id: 'rsShard2', members: [{ _id: 0, host: 'mype-shard2:27017' }] })"
sleep 15

# Enrutador
docker run -d --name mype-mongos --network $RED -p 27030:27017 $IMAGEN mongos --configdb rsCfg/mype-cfg1:27017 --port 27017 --bind_ip_all > /dev/null
esperar mype-mongos

# Registrar los dos shards en el cluster
docker exec mype-mongos mongosh --quiet --eval "
  printjson(sh.addShard('rsShard1/mype-shard1:27017'));
  printjson(sh.addShard('rsShard2/mype-shard2:27017'));"

# Evidencia: los 2 shards registrados
docker exec mype-mongos mongosh --quiet --eval "db.adminCommand({ listShards: 1 }).shards.forEach(function (s) { print(s._id + '  ' + s.host + '  estado=' + s.state); })"
docker ps --filter "name=mype-cfg1" --filter "name=mype-shard" --filter "name=mype-mongos"
