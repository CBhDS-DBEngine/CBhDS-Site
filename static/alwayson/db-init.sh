#!/bin/bash

set -e  

echo "#######    Running set up script ${SQL_SCRIPT}   #######"

SQL_SCRIPT=$INIT_SCRIPT

# Check if SQL_SCRIPT variable is set, if not exit with error
if [ -z "${SQL_SCRIPT}" ]; then
    exit 1
fi

# Run the setup script to create the DB and the schema in the DB
# If this is the primary node, remove the certificate files.
# If docker containers are stopped, but volumes are not removed, this certificate will be persisted

if [ "$SQL_SCRIPT" = "alwayson_primary.sql" ]
then
    rm -f /var/opt/mssql/shared/alwayson_certificate.key 
    rm -f /var/opt/mssql/shared/alwayson_certificate.cert
fi

# Use the SA password from the environment variable
# Use sqlcmd (tools18) to run the SQL script

/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P ${MSSQL_SA_PASSWORD} -d master -i ${SQL_SCRIPT}

echo "#######      Set up script ${SQL_SCRIPT} execution completed     #######"


