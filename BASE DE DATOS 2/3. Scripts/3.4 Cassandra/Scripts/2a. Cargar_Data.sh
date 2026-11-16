#!/bin/bash
# ============================================================
# 2a. Cargar_Data.sh  -  Copia los 5 CSV al nodo y ejecuta "2. Data.cql"
# Ejecutar en WSL, con el cluster arriba (los 3 nodos en UN).
# Los 5 CSV deben estar en la carpeta "csv" junto a este script:
#   - movimientos_sku.csv, historial_stock.csv y alertas_sucursal.csv ya estan
#     (salen de PostgreSQL con "2c. Exportar_PostgreSQL.sql");
#   - ventas_sucursal_dia.csv y ventas_cliente.csv se exportan de Oracle con
#     "2b. Exportar_Oracle.sql" y se copian a esa carpeta.
# ============================================================
CSV_DIR="$(dirname "$0")/csv"
NODO=mype-cass1
USR=cassandra
# La clave del superusuario se pide con entrada oculta; no queda en el archivo.
read -s -p "Clave del superusuario cassandra: " CASS_PW; echo

for f in ventas_sucursal_dia.csv ventas_cliente.csv movimientos_sku.csv historial_stock.csv alertas_sucursal.csv; do
  docker cp "$CSV_DIR/$f" $NODO:/tmp/
done
docker exec $NODO ls -l /tmp/*.csv

docker cp "$(dirname "$0")/2. Data.cql" $NODO:/tmp/2_Data.cql
docker exec $NODO cqlsh -u $USR -p "$CASS_PW" -f /tmp/2_Data.cql
