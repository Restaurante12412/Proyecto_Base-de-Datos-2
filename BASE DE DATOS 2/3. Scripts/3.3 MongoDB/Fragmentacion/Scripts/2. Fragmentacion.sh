#!/bin/bash
# ============================================================
# 2. Fragmentacion.sh  -  Fragmenta ventas_documento y carga los datos
# Ejecutar en WSL desde la carpeta "3.3 MongoDB/Fragmentacion/Scripts",
# despues de "1. Crear_Cluster_Shards.sh". Paso a paso, capturando cada salida.
#
# Orden (importa): primero se crean las colecciones, luego se fragmenta
# ventas_documento VACIA y al final se cargan los datos. Asi MongoDB
# reparte los fragmentos entre los 2 shards desde el inicio y cada venta
# cae en su shard al insertarse.
# ============================================================
S="../../Scripts"
M="docker exec mype-mongos mongosh --quiet"

# ---------- 1. Colecciones, validadores e indices (a traves del enrutador) ----------
docker cp "$S/1. Colecciones.js" mype-mongos:/tmp/1.js
$M --file /tmp/1.js

# ---------- 2. Fragmentar ventas_documento por id_sucursal ----------
docker cp "3. Fragmentacion.js" mype-mongos:/tmp/3.js
docker exec -e PASO=fragmentar mype-mongos mongosh --quiet --file /tmp/3.js

# ---------- 3. Cargar los 2.500 documentos ----------
docker cp "$S/6. Data.js" mype-mongos:/tmp/6.js
$M --file /tmp/6.js

# ---------- 4. Evidencias: reparto, consulta dirigida y consulta general ----------
docker exec -e PASO=evidencias mype-mongos mongosh --quiet --file /tmp/3.js

# ---------- 5. Apagar el entorno cuando ya no se necesite ----------
#   docker stop mype-mongos mype-shard1 mype-shard2 mype-cfg1
# Para borrarlo:
#   docker rm -f mype-mongos mype-shard1 mype-shard2 mype-cfg1
