---------------------------------------------------------------------------------------------
-- PRIMARY (DOCKER - RESTORE BASED SETUP)
---------------------------------------------------------------------------------------------

USE [master];
GO

---------------------------------------------------------------------------------------------
-- RESTORE DATABASE (FROM WINDOWS MOUNTED BACKUP)
---------------------------------------------------------------------------------------------
RAISERROR('Restoring database in RECOVERY mode...', 10, 1) WITH NOWAIT;

RESTORE DATABASE [tpcc]
FROM DISK = N'/var/opt/mssql/seed-backup/tpcc_seed.bak'
WITH
    MOVE 'tpcc'     TO '/var/opt/mssql/data/tpcc.mdf',
    MOVE 'tpcc_log' TO '/var/opt/mssql/data/tpcc_log.ldf',
    RECOVERY,
    REPLACE,
    STATS = 10;
GO

---------------------------------------------------------------------------------------------
-- A NEW FULL BACKUP IS NOT REQUIRED
---------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------
-- LOGIN + USER FOR AAG
---------------------------------------------------------------------------------------------
RAISERROR('Creating login...', 10, 1) WITH NOWAIT;


CREATE LOGIN aoag_login WITH PASSWORD = 'YourStrongPasswordForAAG!';
GO

CREATE USER aoag_user FOR LOGIN aoag_login;
GO

---------------------------------------------------------------------------------------------
-- MASTER KEY
---------------------------------------------------------------------------------------------
RAISERROR('Creating master key...', 10, 1) WITH NOWAIT;


CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStrongPasswordForAAG!';
GO

---------------------------------------------------------------------------------------------
-- CREATE CERTIFICATE FROM PRIMARY
---------------------------------------------------------------------------------------------
RAISERROR('Creating certificate...', 10, 1) WITH NOWAIT;

CREATE CERTIFICATE alwayson_certificate
WITH SUBJECT = 'alwayson_certificate';
GO

BACKUP CERTIFICATE alwayson_certificate
TO FILE = '/var/opt/mssql/shared/alwayson_certificate.cert'
WITH PRIVATE KEY (
    FILE = '/var/opt/mssql/shared/alwayson_certificate.key',
    ENCRYPTION BY PASSWORD = 'YourStrongPasswordForAAG!'
);
GO

---------------------------------------------------------------------------------------------
-- ENDPOINT
---------------------------------------------------------------------------------------------
RAISERROR('Creating HADR endpoint...', 10, 1) WITH NOWAIT;

CREATE ENDPOINT [Hadr_endpoint]
STATE = STARTED
AS TCP (
    LISTENER_PORT = 5022,
    LISTENER_IP = ALL
)
FOR DATA_MIRRORING (
    ROLE = ALL,
    AUTHENTICATION = CERTIFICATE alwayson_certificate,
    ENCRYPTION = REQUIRED ALGORITHM AES
);
GO

GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO [aoag_login];
GO

---------------------------------------------------------------------------------------------
-- CREATE AVAILABILITY GROUP -- CLUSTERLESS MODE
-- In clusterless mode i.e 
--  * For Windows → NO WSFC
--  * For Linux → NO Pacemaker
-- the availability group is created without any cluster type, 
-- and the replicas are added with manual failover mode. 
-- This allows for a simpler setup in environments where clustering is not available or desired.
---------------------------------------------------------------------------------------------
RAISERROR('Creating Availability Group...', 10, 1) WITH NOWAIT;

DECLARE @cmd NVARCHAR(MAX);

SET @cmd = '
CREATE AVAILABILITY GROUP [tpcc_ag]
WITH (
    CLUSTER_TYPE = NONE
)
FOR REPLICA ON
N''mssqlaagnode1'' WITH
(
    ENDPOINT_URL = N''tcp://mssqlaagnode1:5022'',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    SEEDING_MODE = AUTOMATIC,
    FAILOVER_MODE = MANUAL,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
),
N''mssqlaagnode2'' WITH
(
    ENDPOINT_URL = N''tcp://mssqlaagnode2:5022'',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    SEEDING_MODE = AUTOMATIC,
    FAILOVER_MODE = MANUAL,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
);
';

EXEC sp_executesql @cmd;
GO

---------------------------------------------------------------------------------------------
-- ADD DATABASE TO AVAILABILITY GROUP
---------------------------------------------------------------------------------------------
RAISERROR('Adding database in Availability Group...', 10, 1) WITH NOWAIT;

DECLARE @i INT = 0;

WHILE @i < 30
BEGIN
    BEGIN TRY
        ALTER AVAILABILITY GROUP [tpcc_ag] ADD DATABASE [tpcc];
        BREAK;
    END TRY
    BEGIN CATCH
        SET @i += 1;
        WAITFOR DELAY '00:00:5';
    END CATCH
END

---------------------------------------------------------------------------------------------
RAISERROR('PRIMARY SETUP COMPLETED', 10, 1) WITH NOWAIT;
---------------------------------------------------------------------------------------------