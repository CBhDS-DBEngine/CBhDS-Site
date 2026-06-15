#!/bin/bash

# Run db-init.sh script
# Run sqlservr service so docker container does not stop

set -ex

echo "===================================="
echo " Starting SQL Server container"
echo "===================================="

# ------------------------------------
# 1. Start SQL Server in background
# ------------------------------------
echo "[1/3] Starting SQL Server..."

 /opt/mssql/bin/sqlservr &
SQLPID=$!

# ------------------------------------
# 3. Run DB init script
# ------------------------------------
echo "Waiting for SQL Server..."

until /opt/mssql-tools18/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P "${MSSQL_SA_PASSWORD}" \
    -C \
    -Q "SELECT 1" >/dev/null 2>&1
do
    echo "SQL Server not ready..."
    sleep 3
done

echo "SQL Server ready."


echo "[2/3] Running DB initialization..."

sh ./db-init.sh

# ------------------------------------
# 3. Keep container alive while SQL runs
# ------------------------------------
echo "[3/3] Waiting for SQL Server process ($SQLPID)..."

wait $SQLPID