---------------------------------------------------------------------------------------------
-- SECONDARY (DOCKER - RESTORE BASED SETUP)
---------------------------------------------------------------------------------------------

USE [master]
GO

---------------------------------------------------------------------------------------------
-- RESTORE DATABASE (FROM WINDOWS MOUNTED BACKUP)
---------------------------------------------------------------------------------------------
RAISERROR('Restoring database in NORECOVERY mode...', 10, 1) WITH NOWAIT;


RESTORE DATABASE [tpcc]
FROM DISK = N'/var/opt/mssql/seed-backup/tpcc_seed.bak'
WITH
    MOVE 'tpcc'     TO '/var/opt/mssql/data/tpcc.mdf',
    MOVE 'tpcc_log' TO '/var/opt/mssql/data/tpcc_log.ldf',
    NORECOVERY,
    REPLACE,
    STATS = 10;
GO

---------------------------------------------------------------------------------------------
-- LOGIN + USER FOR AAG
---------------------------------------------------------------------------------------------
RAISERROR('Creating login...', 10, 1) WITH NOWAIT;


--create login for aoag
-- this password could also be originate from an environemnt variable passed in to this script through SQLCMD
-- it should however, match the password from the primary script
CREATE LOGIN aoag_login WITH PASSWORD = 'YourStrongPasswordForAAG';
CREATE USER aoag_user FOR LOGIN aoag_login;

---------------------------------------------------------------------------------------------
-- MASTER KEY
---------------------------------------------------------------------------------------------
RAISERROR('Creating master key...', 10, 1) WITH NOWAIT;


-- this time, create the certificate using the certificate file created in the primary node
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStrongPasswordForAAG';
GO

---------------------------------------------------------------------------------------------
-- WAIT FOR CERTIFICATE FILE (IMPORTANT DOCKER FIX)
---------------------------------------------------------------------------------------------

DECLARE @certPath NVARCHAR(255) = '/var/opt/mssql/shared/alwayson_certificate.cert';
DECLARE @keyPath  NVARCHAR(255) = '/var/opt/mssql/shared/alwayson_certificate.key';

WHILE
    NOT EXISTS (
        SELECT 1
        FROM sys.dm_os_file_exists(@certPath)
        WHERE file_exists = 1
    )
    OR
    NOT EXISTS (
        SELECT 1
        FROM sys.dm_os_file_exists(@keyPath)
        WHERE file_exists = 1
    )
BEGIN
    RAISERROR('Waiting for certificate files...', 10, 1) WITH NOWAIT;
    WAITFOR DELAY '00:00:10';
END;


---------------------------------------------------------------------------------------------
-- CREATE CERTIFICATE FROM PRIMARY
---------------------------------------------------------------------------------------------
RAISERROR('Importing certificate...', 10, 1) WITH NOWAIT;

-- this password could also be originate from an environemnt variable passed in to this script through SQLCMD
-- it should however, match the password from the primary script
CREATE CERTIFICATE alwayson_certificate
    AUTHORIZATION aoag_user
    FROM FILE = '/var/opt/mssql/shared/alwayson_certificate.cert'
    WITH PRIVATE KEY (
    FILE = '/var/opt/mssql/shared/alwayson_certificate.key',
    DECRYPTION BY PASSWORD = 'YourStrongPasswordForAAG'
)
GO

---------------------------------------------------------------------------------------------
-- ENDPOINT
---------------------------------------------------------------------------------------------
RAISERROR('Creating HADR endpoint...', 10, 1) WITH NOWAIT;

CREATE ENDPOINT [Hadr_endpoint]
STATE=STARTED
AS TCP (
    LISTENER_PORT = 5022,
    LISTENER_IP = ALL
)
FOR DATA_MIRRORING (
    ROLE = ALL,
    AUTHENTICATION = CERTIFICATE alwayson_certificate,
    ENCRYPTION = REQUIRED ALGORITHM AES
)

GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO [aoag_login];
GO

---------------------------------------------------------------------------------------------
-- JOIN AVAILABILITY GROUP (FIX IMPORTANT)
---------------------------------------------------------------------------------------------
RAISERROR('Joining Availability Group...', 10, 1) WITH NOWAIT;

ALTER AVAILABILITY GROUP [tpcc_ag] JOIN WITH (CLUSTER_TYPE = NONE);
ALTER AVAILABILITY GROUP [tpcc_ag] GRANT CREATE ANY DATABASE;
GO

---------------------------------------------------------------------------------------------
RAISERROR('SECONDARY SETUP COMPLETED', 10, 1) WITH NOWAIT;
---------------------------------------------------------------------------------------------