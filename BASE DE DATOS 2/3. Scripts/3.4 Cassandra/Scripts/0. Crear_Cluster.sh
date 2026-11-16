#!/bin/bash
# ============================================================
# 0. Crear_Cluster.sh  -  Crea el cluster Cassandra de MypeInventario
# Ejecutar en WSL:  bash "0. Crear_Cluster.sh"
# Despues se ejecutan "1. Esquema.cql", "2a. Cargar_Data.sh", etc.
#
# - Cluster MypeCluster con 3 nodos (mype-cass1, mype-cass2, mype-cass3)
#   en el datacenter dc1, que es el que usa el keyspace mype_cassandra
#   (NetworkTopologyStrategy, 'dc1': 3).
# - Imagen cassandra:4.1 (los snapshots usan el formato "nb" de la 4.x).
# - Los nodos se levantan UNO POR UNO: cada uno debe quedar en estado UN
#   antes de iniciar el siguiente; si se inician juntos chocan al unirse.
# - Memoria limitada a 1 GB por nodo para que los 3 entren en una laptop.
# - La autenticacion se activa despues con "5d_Activar_Autenticacion.sh".
# ============================================================
RED=mype-cass-net
IMAGEN=cassandra:4.1

if docker ps -a --format '{{.Names}}' | grep -q '^mype-cass[123]$'; then
  echo "Ya existen contenedores mype-cass. Para empezar de cero:"
  echo "  docker rm -f mype-cass1 mype-cass2 mype-cass3"
  echo "  docker volume rm mype_cass_data1 mype_cass_data2 mype_cass_data3"
  exit 1
fi

docker network create $RED > /dev/null 2>&1

# Espera a que el cluster tenga N nodos en estado UN (Up / Normal)
esperar_un() {
  local esperado=$1
  for i in $(seq 1 60); do
    local n
    n=$(docker exec mype-cass1 nodetool status 2>/dev/null | grep -c '^UN')
    if [ "$n" -ge "$esperado" ]; then echo "  nodos en UN: $n"; return 0; fi
    sleep 5
  done
  echo "  El nodo no llego a UN en 5 minutos. Revisar: docker logs mype-cass$esperado"
  exit 1
}

for i in 1 2 3; do
  echo "Iniciando mype-cass$i ..."
  docker volume create mype_cass_data$i > /dev/null
  docker run -d --name mype-cass$i --network $RED \
    -e CASSANDRA_CLUSTER_NAME=MypeCluster \
    -e CASSANDRA_DC=dc1 \
    -e CASSANDRA_RACK=rack1 \
    -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch \
    -e CASSANDRA_SEEDS=mype-cass1 \
    -e MAX_HEAP_SIZE=1G \
    -e HEAP_NEWSIZE=200M \
    -v mype_cass_data$i:/var/lib/cassandra \
    $IMAGEN > /dev/null
  esperar_un $i
done

# Evidencia: los 3 nodos en UN dentro del datacenter dc1
docker exec mype-cass1 nodetool status
docker exec mype-cass1 nodetool describecluster | head -n 8
docker ps --filter "name=mype-cass"
