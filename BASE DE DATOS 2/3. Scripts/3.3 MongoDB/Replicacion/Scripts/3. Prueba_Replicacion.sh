#!/bin/bash
# ============================================================
# 3. Prueba_Replicacion.sh  -  Prueba de replicacion asincronica en MongoDB
# Ejecutar paso a paso (copiar cada bloque y capturar la salida).
# Requiere el replica set de "1. Crear_ReplicaSet.sh" y las colecciones
# creadas con "1. Colecciones.js".
#
# Que demuestra:
#   A. Un dato escrito en el primario aparece en los secundarios.
#   B. Con un secundario caido el primario sigue aceptando escrituras
#      (no espera a esa replica): la replicacion es asincronica.
#   C. Al volver, el secundario se pone al dia solo, copiando el oplog.
#   D. Si cae el primario, un secundario es elegido como nuevo primario.
# ============================================================
# La clave del administrador se pide una sola vez, con entrada oculta; no queda en el archivo.
read -s -p "Contrasena de admin_mype: " MONGO_PW; echo

AUT="-u admin_mype -p $MONGO_PW --authenticationDatabase admin --quiet"
URI="mongodb://mype-mongo1:27017,mype-mongo2:27017,mype-mongo3:27017/mype_inventario?replicaSet=rsMype"
ROLES="rs.status().members.forEach(function (m) { print(m.name + '  ' + m.stateStr + '  salud=' + m.health); })"
# Documento de prueba (cumple el validador de clientes_perfil)
DOC="{ _id: Long(900001), id_negocio: Long(1), nombres: 'PRUEBA_REPLICACION' }"
LEER="db.getMongo().setReadPref('secondary'); printjson(db.getSiblingDB('mype_inventario').clientes_perfil.findOne({ _id: Long(900001) }, { nombres: 1 }))"

# ---------- 0. Estado inicial: 1 PRIMARY y 2 SECONDARY ----------
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "$ROLES"

# ---------- A. Escribir en el primario y leer en cada secundario ----------
# w: 1 = el primario confirma sin esperar a los secundarios (asincronica)
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "printjson(db.clientes_perfil.insertOne($DOC, { writeConcern: { w: 1 } }))"
# Lectura directa en cada secundario (conexion a ese nodo, no al replica set)
docker exec mype-mongo2 mongosh $AUT --eval "$LEER"
docker exec mype-mongo3 mongosh $AUT --eval "$LEER"

# ---------- B. Apagar un secundario: el primario sigue escribiendo ----------
docker stop mype-mongo3
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "$ROLES"            # mype-mongo3 sale como no disponible
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "printjson(db.clientes_perfil.updateOne({ _id: Long(900001) }, { \$set: { apellidos: 'ESCRITO_CON_NODO_CAIDO' } }, { writeConcern: { w: 1 } }))"
docker exec mype-mongo2 mongosh $AUT --eval "db.getMongo().setReadPref('secondary'); printjson(db.getSiblingDB('mype_inventario').clientes_perfil.findOne({ _id: Long(900001) }))"

# ---------- C. Levantar el secundario: se pone al dia sin intervencion ----------
docker start mype-mongo3
sleep 20
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "$ROLES"            # los 3 nodos con salud=1
docker exec mype-mongo3 mongosh $AUT --eval "db.getMongo().setReadPref('secondary'); printjson(db.getSiblingDB('mype_inventario').clientes_perfil.findOne({ _id: Long(900001) }))"
# Debe mostrar apellidos: 'ESCRITO_CON_NODO_CAIDO', escrito mientras estaba apagado
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "rs.printSecondaryReplicationInfo()"

# ---------- D. (Opcional) Caida del primario: eleccion automatica ----------
docker stop mype-mongo1
sleep 20
docker exec mype-mongo2 mongosh $AUT --eval "$ROLES"                   # mype-mongo2 o mype-mongo3 pasa a PRIMARY
docker start mype-mongo1
sleep 30
docker exec mype-mongo1 mongosh $AUT --eval "$ROLES"                   # mype-mongo1 vuelve y recupera PRIMARY (prioridad 2)

# ---------- E. Borrar el documento de prueba ----------
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "printjson(db.clientes_perfil.deleteOne({ _id: Long(900001) }))"
docker exec mype-mongo1 mongosh "$URI" $AUT --eval "print('clientes: ' + db.clientes_perfil.countDocuments({}))"
