#!/bin/bash
# ============================================================
# 0. Crear_Contenedor.sh  -  Crea el contenedor PostgreSQL de MypeInventario
# Ejecutar en WSL:  bash "0. Crear_Contenedor.sh"
# Despues se ejecutan "1. Base_datos.sql", "2. Tablas.sql", etc.
#
# - Imagen postgres:16 (el script 5 usa INHERIT FALSE / SET FALSE, PG 16+).
# - No se define POSTGRES_DB: la base "MypeInventario" la crea el script 1.
# - Puerto 5433 en el host (el 5432 puede estar ocupado por otro proyecto).
# - La clave del superusuario se pide con entrada oculta y no se guarda en
#   archivos (queda visible en "docker inspect"; es aceptable en el laboratorio).
# - Volumenes: mype_pg_data (datos) y mype_pg_backups (para pg_dump, paso 7).
# ============================================================
NODO=mype-postgres
PUERTO=5433

if docker ps -a --format '{{.Names}}' | grep -qx "$NODO"; then
  echo "Ya existe el contenedor $NODO. Para empezar de cero:"
  echo "  docker rm -f $NODO && docker volume rm mype_pg_data mype_pg_backups"
  exit 1
fi

read -s -p "Contrasena para el superusuario postgres (solo letras y numeros): " P1; echo
read -s -p "Repetir contrasena: " P2; echo
if [ "$P1" != "$P2" ]; then echo "Las contrasenas no coinciden."; exit 1; fi

docker volume create mype_pg_data > /dev/null
docker volume create mype_pg_backups > /dev/null

docker run -d --name $NODO \
  -e POSTGRES_PASSWORD="$P1" \
  -p $PUERTO:5432 \
  -v mype_pg_data:/var/lib/postgresql/data \
  -v mype_pg_backups:/backups \
  postgres:16

# Esperar a que acepte conexiones TCP (durante la inicializacion solo escucha por socket)
for i in $(seq 1 30); do
  docker exec $NODO pg_isready -h 127.0.0.1 -U postgres -q && break
  sleep 2
done

docker exec $NODO pg_isready -h 127.0.0.1 -U postgres
docker exec $NODO psql -U postgres -c "SELECT version();"
docker ps --filter "name=$NODO"
