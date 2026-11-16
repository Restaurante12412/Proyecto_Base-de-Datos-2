#!/bin/bash
# ============================================================
# 5b_Usuarios.sh  -  Crea los 5 usuarios y les asigna su rol.
# Las contrasenas se piden con entrada oculta; no se guardan en archivos.
# Usar solo letras y numeros (sin comillas simples, espacios ni $).
# Ejecutar DESPUES de "5. Usuarios.cql".
# ============================================================
# La clave del superusuario se pide una sola vez, con entrada oculta; no queda en el archivo.
read -s -p "Clave del superusuario cassandra: " CASS_PW; echo

read -s -p "Contrasena para ericson_damian: " P1; echo
read -s -p "Contrasena para pedro_zavaleta: " P2; echo
read -s -p "Contrasena para jose_callupe:   " P3; echo
read -s -p "Contrasena para keyden_navarro: " P4; echo
read -s -p "Contrasena para yemima_reyes:   " P5; echo
docker exec -i mype-cass1 cqlsh -u cassandra -p "$CASS_PW" <<CQL
CREATE ROLE IF NOT EXISTS ericson_damian WITH PASSWORD = '$P1' AND LOGIN = true;
CREATE ROLE IF NOT EXISTS pedro_zavaleta WITH PASSWORD = '$P2' AND LOGIN = true;
CREATE ROLE IF NOT EXISTS jose_callupe   WITH PASSWORD = '$P3' AND LOGIN = true;
CREATE ROLE IF NOT EXISTS keyden_navarro WITH PASSWORD = '$P4' AND LOGIN = true;
CREATE ROLE IF NOT EXISTS yemima_reyes   WITH PASSWORD = '$P5' AND LOGIN = true;
GRANT admin_oracle          TO ericson_damian;
GRANT gestor_compras_oracle TO pedro_zavaleta;
GRANT gestor_ventas_oracle  TO jose_callupe;
GRANT analista_oracle       TO keyden_navarro;
GRANT consulta_oracle       TO yemima_reyes;
CQL

# Si algun usuario da "Bad credentials" (error de tecleo al escribir la clave):
# docker exec mype-cass1 cqlsh -u cassandra -p "$CASS_PW" -e "ALTER ROLE yemima_reyes WITH PASSWORD = 'NuevaClave1' AND LOGIN = true;"
