#!/bin/bash
# ============================================================
# 6. Backups_Restore.sh  -  Respaldo y restauracion con nodetool snapshot
# Keyspace: mype_cassandra   Cluster: 3 nodos, RF 3, autenticacion activa
# Ejecutar paso a paso (capturar cada resultado).
# ============================================================
# La clave del superusuario se pide una sola vez, con entrada oculta; no queda en el archivo.
read -s -p "Clave del superusuario cassandra: " CASS_PW; echo

SNAP=backup_20261115       # cambiar la fecha en cada backup nuevo
SU="docker exec mype-cass1 cqlsh -u cassandra -p $CASS_PW"
NT="docker exec mype-cass1 nodetool -u cassandra -pw $CASS_PW"

# ---------- 1. Conteos ANTES del backup (referencia) ----------
for t in alertas_por_sucursal movimientos_por_sku historial_stock_por_sku ventas_por_sucursal_dia ventas_por_cliente; do
  echo -n "$t: "
  $SU -e "SELECT COUNT(*) FROM mype_cassandra.$t;" 2>/dev/null | sed -n '4p'
done
# Esperado: 500 / 500 / 500 / 100 / 100

# ---------- 2. Snapshot ----------
# Los snapshots son hard links: instantaneos y casi sin espacio extra.
# Con RF 3 cada nodo guarda copia de los datos; en produccion se repite en cada nodo:
#   docker exec mype-cass2 nodetool -u cassandra -pw "$CASS_PW" snapshot -t $SNAP mype_cassandra
#   docker exec mype-cass3 nodetool -u cassandra -pw "$CASS_PW" snapshot -t $SNAP mype_cassandra
$NT snapshot -t $SNAP mype_cassandra

# ---------- 3. Comprobar que existe ----------
$NT listsnapshots
docker exec mype-cass1 bash -c "ls -lh /var/lib/cassandra/data/mype_cassandra/ventas_por_cliente-*/snapshots/$SNAP/"
# Debe verse manifest.json, schema.cql y los nb-1-big-*.db

# ---------- 4. Simular la perdida de datos ----------
$SU -e "TRUNCATE mype_cassandra.ventas_por_cliente;"
$SU -e "SELECT COUNT(*) FROM mype_cassandra.ventas_por_cliente;"      # 0
# (TRUNCATE genera ademas su propio snapshot automatico: auto_snapshot)

# ---------- 5. Restaurar desde el snapshot ----------
# Copiar SOLO los nb-* (no manifest.json ni schema.cql) a la carpeta de la tabla
docker exec mype-cass1 bash -c "D=\$(ls -d /var/lib/cassandra/data/mype_cassandra/ventas_por_cliente-*); cp \$D/snapshots/$SNAP/nb-* \$D/ && chown cassandra:cassandra \$D/nb-* && ls -lh \$D"

# Cargar los SSTables sin reiniciar el nodo
$NT refresh mype_cassandra ventas_por_cliente

# ---------- 6. Verificar ----------
$SU -e "SELECT COUNT(*) FROM mype_cassandra.ventas_por_cliente;"      # 100

# ---------- 7. Propagar a los otros nodos (la restauracion fue solo en mype-cass1) ----------
$NT repair -full mype_cassandra ventas_por_cliente
$SU -e "CONSISTENCY ALL; SELECT COUNT(*) FROM mype_cassandra.ventas_por_cliente;"   # 100 con las 3 replicas

# ---------- Restaurar TODO el keyspace (si hiciera falta) ----------
# Repetir 4-5 para cada tabla (ventas_por_sucursal_dia, movimientos_por_sku,
# historial_stock_por_sku, alertas_por_sucursal) y luego repair -full del keyspace.
# Si el esquema se hubiera perdido: ejecutar primero "1. Esquema.cql" (o el schema.cql del snapshot).

# ---------- 8. Copiar el backup a la carpeta "4. Backups" del repositorio ----------
# Ejecutar desde la carpeta "3.4 Cassandra/Scripts". Empaqueta el snapshot de las
# 5 tablas (incluye el schema.cql de cada una) y lo copia fuera del contenedor.
DEST="../../../4. Backups/Cassandra"
mkdir -p "$DEST"
docker exec mype-cass1 bash -c "cd /var/lib/cassandra/data/mype_cassandra && tar czf /tmp/mype_cassandra_$SNAP.tar.gz */snapshots/$SNAP"
docker cp mype-cass1:/tmp/mype_cassandra_$SNAP.tar.gz "$DEST/"
$NT listsnapshots > "$DEST/mype_cassandra_$SNAP.log"
ls -lh "$DEST"

# ---------- Borrar el snapshot cuando ya no se necesite ----------
# $NT clearsnapshot -t $SNAP mype_cassandra
