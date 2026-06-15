#!/bin/bash

set -euo pipefail

# Function to log messages with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] : $1"
}

AG_NAME="tpcc_ag"
NODE1="mssqlaagnode1"
NODE2="mssqlaagnode2"
MSSQL_SA_PASSWORD="YourStrongSAPassword"

# MS does not provide an image with tools v18, so we use an older version for now
# but this is acceptable since we only use sqlcmd to check liveness and run a few commands
SQLCMD="/opt/mssql-tools/bin/sqlcmd"


echo "#### AAG WITNESS STARTED ####"

# ---------------------------------------------------
# WAIT NODES
# ---------------------------------------------------
until $SQLCMD -S "$NODE1" -U sa -C -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting mssqlaagnode1..."
  sleep 5
done

until $SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" >/dev/null 2>&1; do
  echo "Waiting mssqlaagnode2..."
  sleep 5
done

echo "====> mssqlaagnode1 & mssqlaagnode2 reachable. This is cool, let's start the witness loop."

# ---------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------
while true; do

# ---------------------------------------------------
# 1. NODE STATUS (UP / DOWN)
# ---------------------------------------------------
if $SQLCMD -S "$NODE1" -U sa -C -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" >/dev/null 2>&1; then
  NODE1_STATE="UP"
else
  NODE1_STATE="DOWN"
fi

if $SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" >/dev/null 2>&1; then
  NODE2_STATE="UP"
else
  NODE2_STATE="DOWN"
fi

echo "---------------------------------------------------"
log "mssqlaagnode1: $NODE1_STATE & mssqlaagnode2: $NODE2_STATE"

# ---------------------------------------------------
# CASE 1 - HEALTHY + SPLIT BRAIN GUARD 
# ---------------------------------------------------

if [[ ( "$NODE1_STATE" == "UP" && "$NODE2_STATE" == "UP" ) ]]; then

  NODE1_ROLE=$($SQLCMD -S "$NODE1" -U sa -C -P "$MSSQL_SA_PASSWORD" -h -1 -W -Q "
    SET NOCOUNT ON;
    SELECT role_desc
    FROM sys.dm_hadr_availability_replica_states ars
    JOIN sys.availability_replicas ar
      ON ars.replica_id = ar.replica_id
    WHERE ar.replica_server_name = '$NODE1';
    " | tr -d '[:space:]' | sed -e '/^$/d' || echo "UNKNOWN"
  )

  NODE2_ROLE=$($SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" -h -1 -W -Q "
    SET NOCOUNT ON;
    SELECT role_desc
    FROM sys.dm_hadr_availability_replica_states ars
    JOIN sys.availability_replicas ar
      ON ars.replica_id = ar.replica_id
    WHERE ar.replica_server_name = '$NODE2';
    " | tr -d '[:space:]' | sed -e '/^$/d' || echo "UNKNOWN"
  )


  if [[ ( "$NODE1_ROLE" == "PRIMARY" && "$NODE2_ROLE" == "PRIMARY" ) ]]; then
    log "mssqlaagnode1: $NODE1_ROLE & mssqlaagnode2: $NODE2_ROLE"
    log "Potential SPLIT BRAIN detected"
  else 
    # If NODE1_ROLE or NODE2_ROLE are empty (or not detected), force UNKNOWN
    if [[ -z "$NODE1_ROLE" ]]; then NODE1_ROLE="UNKNOWN"; fi
    if [[ -z "$NODE2_ROLE" ]]; then NODE2_ROLE="UNKNOWN"; fi

    log "mssqlaagnode1: $NODE1_ROLE & mssqlaagnode2: $NODE2_ROLE"
    if [[ ( "$NODE1_ROLE" == "PRIMARY" && "$NODE2_ROLE" == "SECONDARY" ) ]]; then
      log "Cluster HEALTHY -> NO ACTION - Re-evaluating in 10 seconds"  
    fi

  fi

fi


# ---------------------------------------------------
# CASE 1: NODE1 UP & NODE2 DOWN -> NO ACTION
# ---------------------------------------------------
if [[ "$NODE1_STATE" == "UP" && "$NODE2_STATE" == "DOWN" ]]; then
  log "mssqlaagnode1: $NODE1_ROLE -> Cluster DEGRADED"
  log "MANUAL action REQUIRED. Re-evaluating in 10 seconds"
fi

# CASE 2: NODE1 DOWN -> FAILOVER TO NODE2
# ---------------------------------------------------

if [[ "$NODE1_STATE" == "DOWN" && "$NODE2_STATE" == "UP" ]]; then

  PRIMARY=$($SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" -h -1 -W -Q "
    SET NOCOUNT ON;
    SELECT ar.replica_server_name
    FROM sys.dm_hadr_availability_replica_states ars
    JOIN sys.availability_replicas ar
      ON ars.replica_id = ar.replica_id
    WHERE ars.role_desc = 'PRIMARY';
    " | tr -d '[:space:]'
  )

  if [[ "$PRIMARY" != "$NODE2" ]]; then

    log "mssqlaagnode1 DOWN & mssqlaagnode2 UP -> FAILOVER to mssqlaagnode2"

    $SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" \
    -Q "ALTER AVAILABILITY GROUP [$AG_NAME] FORCE_FAILOVER_ALLOW_DATA_LOSS;"

    log "Removing mssqlaagnode1 from AG on mssqlaagnode2"

    $SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" \
    -Q "ALTER AVAILABILITY GROUP [$AG_NAME] REMOVE REPLICA ON N'$NODE1';"

  else
    log "mssqlaagnode2 already PRIMARY -> Cluster DEGRADED"
    log "MANUAL action REQUIRED. Re-evaluating in 10 seconds"
  fi

fi

# ---------------------------------------------------
# CASE 3: NODE1 BACK -> CLEANUP AFTER FAILOVER
# ---------------------------------------------------
# We want cleanup to trigger after a failover, so we make sure NODE2 is PRIMARY.

if [[ "$NODE1_STATE" == "UP" && "$NODE2_STATE" == "UP" ]]; then

  # Determine current PRIMARY replica (so cleanup triggers after a failover).
  PRIMARY_NODE=$($SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" -h -1 -W -Q "
    SET NOCOUNT ON;
    SELECT ar.replica_server_name
    FROM sys.dm_hadr_availability_replica_states ars
    JOIN sys.availability_replicas ar
      ON ars.replica_id = ar.replica_id
    WHERE ars.role_desc = 'PRIMARY';
    " | tr -d '[:space:]' || echo "")

  # If NODE2 is the PRIMARY, CLEANUP on NODE1
  # if local AG exists
  if [[ "$PRIMARY_NODE" == "$NODE2" ]]; then

    # Cleanup is based on whether node1 still has the AG locally.
    EXISTS=$($SQLCMD -S "$NODE1" -U sa -C -P "$MSSQL_SA_PASSWORD" -h -1 -W -Q "
      SET NOCOUNT ON;
      SELECT COUNT(*) FROM sys.availability_groups WHERE name = '$AG_NAME';
      " | tr -d '[:space:]' || echo 0)

     # Optional: also check if node1 is currently part of the AG on the PRIMARY.
    # (Use this as an extra guard / debug helper.)
    NODE1_IN_PRIMARY=$($SQLCMD -S "$NODE2" -U sa -C -P "$MSSQL_SA_PASSWORD" -h -1 -W -Q "
      SET NOCOUNT ON;
      SELECT COUNT(*)
      FROM sys.availability_replicas
      WHERE replica_server_name = '$NODE1';
      " | tr -d '[:space:]' || echo 0)

    if [[ "$EXISTS" -gt 0 ]]; then
      log "mssqlaagnode1 returns while mssqlaagnode2 is PRIMARY"
      log "OFFLINE + DROP of the group on mssqlaagnode1"

      $SQLCMD -S "$NODE1" -U sa -C -P "$MSSQL_SA_PASSWORD" -Q "
        ALTER AVAILABILITY GROUP [$AG_NAME] OFFLINE;
        DROP AVAILABILITY GROUP [$AG_NAME];
        "
    else
      log "mssqlaagnode1: AG not found"
      log "Cluster in DEGRADED state"
      log "Manual intervention REQUIRED - Re-evaluating in 10 seconds"
    fi
  fi

fi

sleep 10

done