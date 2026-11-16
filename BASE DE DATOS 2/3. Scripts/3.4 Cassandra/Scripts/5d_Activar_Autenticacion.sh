#!/bin/bash
# ============================================================
# 5d_Activar_Autenticacion.sh  -  Prerrequisitos del Paso 8
# Activa PasswordAuthenticator y CassandraAuthorizer en los 3 nodos y
# sube system_auth a RF 3. Ejecutar ANTES de "5. Usuarios.cql".
# El cambio vive en cassandra.yaml del contenedor: sobrevive a
# docker stop/start, pero se pierde con docker rm.
# ============================================================
# La clave del superusuario se pide una sola vez, con entrada oculta; no queda en el archivo.
read -s -p "Clave del superusuario cassandra (recien activada la autenticacion es: cassandra): " CASS_PW; echo

for n in mype-cass1 mype-cass2 mype-cass3; do
  docker exec $n sed -i 's/^authenticator:.*/authenticator: PasswordAuthenticator/' /etc/cassandra/cassandra.yaml
  docker exec $n sed -i 's/^authorizer:.*/authorizer: CassandraAuthorizer/' /etc/cassandra/cassandra.yaml
done

# Reiniciar UNO POR UNO esperando UN entre cada uno
docker restart mype-cass1; sleep 60; docker exec mype-cass1 nodetool status
docker restart mype-cass2; sleep 60; docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" status
docker restart mype-cass3; sleep 60; docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" status

# Login por defecto: cassandra / cassandra
docker exec mype-cass1 cqlsh -u cassandra -p "$CASS_PW" -e "ALTER KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3};"
docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" repair -full system_auth
docker exec mype-cass1 cqlsh -u cassandra -p "$CASS_PW" -e "SELECT keyspace_name, replication FROM system_schema.keyspaces WHERE keyspace_name='system_auth';"   # debe decir 'dc1': '3'

# Opcional: cambiar la clave por defecto del superusuario
# docker exec mype-cass1 cqlsh -u cassandra -p "$CASS_PW" -e "ALTER ROLE cassandra WITH PASSWORD = 'NuevaClave';"
