#!/bin/bash
# ============================================================
# 0. Ejecutar.sh  -  Ejecuta un script .js de MongoDB dentro del replica set
# El entorno se crea antes con "../Replicacion/Scripts/1. Crear_ReplicaSet.sh".
#
# Uso (en WSL, desde la carpeta "3.3 MongoDB/Scripts"):
#   bash "0. Ejecutar.sh" "1. Colecciones.js"            ejecuta el archivo como admin_mype
#   bash "0. Ejecutar.sh" "4. Funciones.js" --shell      lo ejecuta y deja abierta la consola
#   bash "0. Ejecutar.sh"                                abre la consola sin ejecutar nada
#   USUARIO=yemima_reyes BASE_AUT=mype_inventario bash "0. Ejecutar.sh"     consola con otro usuario
#
# Copia el archivo al contenedor mype-mongo1 y lo ejecuta conectado al
# replica set completo, de modo que siempre escribe en el nodo PRIMARY
# aunque haya cambiado. La contrasena la pide mongosh (entrada oculta).
#
# Orden de los scripts: 1. Colecciones, 6. Data, 5. Usuario, 3. Consultas,
# 4. Funciones (con --shell) y 7. Backups_Restore.sh.
# ============================================================
ARCHIVO="$1"
OPCION="$2"
USUARIO="${USUARIO:-admin_mype}"
BASE_AUT="${BASE_AUT:-admin}"
URI="mongodb://mype-mongo1:27017,mype-mongo2:27017,mype-mongo3:27017/mype_inventario?replicaSet=rsMype"

if [ -z "$ARCHIVO" ]; then
  docker exec -it mype-mongo1 mongosh "$URI" -u "$USUARIO" --authenticationDatabase "$BASE_AUT"
  exit $?
fi

if [ ! -f "$ARCHIVO" ]; then echo "No existe el archivo: $ARCHIVO"; exit 1; fi

docker cp "$ARCHIVO" mype-mongo1:/tmp/script.js
if [ "$OPCION" = "--shell" ]; then
  docker exec -it mype-mongo1 mongosh "$URI" -u "$USUARIO" --authenticationDatabase "$BASE_AUT" --file /tmp/script.js --shell
else
  docker exec -it mype-mongo1 mongosh "$URI" -u "$USUARIO" --authenticationDatabase "$BASE_AUT" --file /tmp/script.js
fi
