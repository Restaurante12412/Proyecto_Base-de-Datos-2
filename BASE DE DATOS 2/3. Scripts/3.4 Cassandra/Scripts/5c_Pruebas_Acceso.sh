#!/bin/bash
# ============================================================
# 5c_Pruebas_Acceso.sh  -  Verificaciones y pruebas de acceso (capturas)
# Ejecutar UN comando a la vez. Reemplazar CLAVE_xxx por la contrasena
# de cada usuario (o quitar -p para que la pida).
# ============================================================
# La clave del superusuario se pide una sola vez, con entrada oculta; no queda en el archivo.
read -s -p "Clave del superusuario cassandra: " CASS_PW; echo

SU="docker exec mype-cass1 cqlsh -u cassandra -p $CASS_PW"

# --- Verificaciones (superusuario) ---
$SU -e "LIST ROLES;"                                  # 11 filas: 5 roles, 5 usuarios, cassandra
$SU -e "LIST ROLES OF keyden_navarro;"                # keyden_navarro + analista_oracle
$SU -e "LIST ALL PERMISSIONS OF admin_oracle;"        # sin MODIFY ni ALL PERMISSIONS
$SU -e "LIST ALL PERMISSIONS OF gestor_ventas_oracle;"# MODIFY solo en ventas_por_sucursal_dia y ventas_por_cliente

# --- analista (keyden_navarro): permitido = 3 / denegado = Unauthorized ---
docker exec -it mype-cass1 cqlsh -u keyden_navarro -p CLAVE_KEYDEN -e "SELECT COUNT(*) FROM mype_cassandra.ventas_por_sucursal_dia WHERE id_sucursal = 1 AND fecha_dia = '2026-08-27';"
docker exec -it mype-cass1 cqlsh -u keyden_navarro -p CLAVE_KEYDEN -e "SELECT * FROM mype_cassandra.ventas_por_cliente WHERE id_cliente = 1;"

# --- consulta (yemima_reyes): lee alertas = 12 / DELETE = Unauthorized ---
docker exec -it mype-cass1 cqlsh -u yemima_reyes -p CLAVE_YEMIMA -e "SELECT COUNT(*) FROM mype_cassandra.alertas_por_sucursal WHERE id_sucursal = 1 AND estado = 'PENDIENTE';"
docker exec -it mype-cass1 cqlsh -u yemima_reyes -p CLAVE_YEMIMA -e "DELETE FROM mype_cassandra.alertas_por_sucursal WHERE id_sucursal = 1 AND estado = 'PENDIENTE';"

# --- compras (pedro_zavaleta): lee alertas = 12 / ventas = Unauthorized ---
docker exec -it mype-cass1 cqlsh -u pedro_zavaleta -p CLAVE_PEDRO -e "SELECT COUNT(*) FROM mype_cassandra.alertas_por_sucursal WHERE id_sucursal = 1 AND estado = 'PENDIENTE';"
docker exec -it mype-cass1 cqlsh -u pedro_zavaleta -p CLAVE_PEDRO -e "SELECT * FROM mype_cassandra.ventas_por_sucursal_dia WHERE id_sucursal = 1 AND fecha_dia = '2026-08-27';"

# --- Limpieza de la primera version de roles (ya ejecutada; dejar por si se repite) ---
# $SU -e "DROP ROLE IF EXISTS admin_mype; DROP ROLE IF EXISTS vendedor_mype; DROP ROLE IF EXISTS almacen_mype; DROP ROLE IF EXISTS analista_mype; DROP ROLE IF EXISTS rol_admin; DROP ROLE IF EXISTS rol_ventas; DROP ROLE IF EXISTS rol_inventario; DROP ROLE IF EXISTS rol_consulta;"
