#!/bin/bash
# ============================================================
# 3b. Replicacion.sh  -  Orden de la prueba de replicacion asincronica
# Ejecutar paso a paso (copiar cada bloque y capturar la salida).
# Las sentencias CQL estan en "3. Replicacion.cql".
# ============================================================
# La clave del superusuario se pide una sola vez, con entrada oculta; no queda en el archivo.
read -s -p "Clave del superusuario cassandra: " CASS_PW; echo

C="docker exec mype-cass1 cqlsh -u cassandra -p $CASS_PW"

# 0. Estado inicial: los 3 nodos en UN
docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" status mype_cassandra

# 1. Apagar el tercer nodo y comprobar que sale DN
docker stop mype-cass3
docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" status

# 2. INSERT con LOCAL_QUORUM + lectura en mype-cass1 (PASO A del .cql)
$C -e "CONSISTENCY LOCAL_QUORUM; INSERT INTO mype_cassandra.ventas_por_sucursal_dia (id_sucursal, fecha_dia, fecha_venta, id_venta, id_empleado, canal, estado) VALUES (1, '2026-11-15', '2026-11-15 10:00:00', 900001, 37, 'PRUEBA_REPLICACION', 'COMPLETADA');"
$C -e "SELECT id_venta, canal, estado FROM mype_cassandra.ventas_por_sucursal_dia WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15';"

# 3. Levantar el nodo y esperar los 3 en UN
docker start mype-cass3
sleep 40
docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" status

# 4. Leer en mype-cass3 SIN repair (PASO B): debe aparecer la fila 900001
docker exec mype-cass3 cqlsh -u cassandra -p "$CASS_PW" -e "CONSISTENCY ONE; SELECT id_venta, canal, estado FROM mype_cassandra.ventas_por_sucursal_dia WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15';"

# 5. Borrar la fila de prueba (PASO C) y comprobar 0 rows
$C -e "CONSISTENCY LOCAL_QUORUM; DELETE FROM mype_cassandra.ventas_por_sucursal_dia WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15' AND fecha_venta = '2026-11-15 10:00:00' AND id_venta = 900001;"
$C -e "SELECT id_venta FROM mype_cassandra.ventas_por_sucursal_dia WHERE id_sucursal = 1 AND fecha_dia = '2026-11-15';"

# Opcional (si el nodo tardo en ponerse al dia): repair manual
# docker exec mype-cass1 nodetool -u cassandra -pw "$CASS_PW" repair -full mype_cassandra
