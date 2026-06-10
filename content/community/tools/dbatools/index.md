---
title: "dbatools & dbachecks in Practice"
summary: "Leveraging dbatools & dbachecks for Configuration Integrity"

categories: ["Automation"]
tags: ["SQL Server", "dbatools", "dbachecks", "Powershell",'Configuration integrity", "Heathcheck"]
---

## 1/ Reminder:
Refer to my previous article to deploy dbatools in Docker - https://cbhds-dbengine.github.io/CBhDS-Site/docker-sqlserver-lab/dbatools/

In my configuration, the SQL Server instance runs in another container named mssql2025 and the port is 1468. 

Authentication: SQL Server using sa login.

I do not want to manage docker subnet, so I use the "host.docker.internal" feature to interconnect the SQL Server container and the dbatools one.

```bash 
PS> $secstr = ConvertTo-SecureString "SA_PASSWORD!" -AsPlainText -Force
PS> $cred = New-Object System.Management.Automation.PSCredential("sa", $secstr)
PS> Connect-DbaInstance -SqlInstance "host.docker.internal,1468" -SqlCredential $cred -TrustServerCertificate
And to bypass ceetificates: 
$server = Connect-DbaInstance -SqlInstance "host.docker.internal,1468" -SqlCredential $cred -TrustServerCertificate
```
## 2/ Usage

### Db list - I use this command to check my connection, in fact. 
```bash 
PS /> Get-DbaDatabase -SqlInstance $server                                                                               
ComputerName       : host.docker.internal
InstanceName       : MSSQLSERVER
SqlInstance        : mssql2025
Name               : master
Status             : Normal
IsAccessible       : True
RecoveryModel      : Simple
LogReuseWaitStatus : Nothing
SizeMB             : 6.625
Compatibility      : Version170
Collation          : SQL_Latin1_General_CP1_CI_AS
...
```

### Db list with selected columns - An example to select a subset of information
```bash 
PS> Get-DbaDatabase -SqlInstance $server -ExcludeSystem | Select Name, Size, LastFullBackup
```

### Instance properties - Useful for deploying additional instances across environments to ensure configuration consistency.
```bash 
PS /> Get-DbaInstanceProperty  -SqlInstance $server

ComputerName : host.docker.internal
InstanceName : MSSQLSERVER
SqlInstance  : mssql2025
Name         : BuildNumber
Value        : 1000
PropertyType : Information

ComputerName : host.docker.internal
InstanceName : MSSQLSERVER
SqlInstance  : mssql2025
Name         : Edition
Value        : Enterprise Developer Edition (64-bit)
PropertyType : Information
...
```

### Tables list - Well ...
```bash 
PS> (Get-DbaDbTable -SqlInstance $server -Database tpcc).Columns | Select-Object Parent, Name, DataType
Parent           Name           DataType
------           ----           --------
[dbo].[customer] c_id           int
[dbo].[customer] c_d_id         tinyint
[dbo].[customer] c_w_id         int
[dbo].[customer] c_discount     smallmoney
[dbo].[customer] c_credit_lim   money
[dbo].[customer] c_last         char
[dbo].[customer] c_first        char
[dbo].[customer] c_credit       char
[dbo].[customer] c_balance      money
...
```

### Patching reference - Useful for quickly comparing the current config state with the target patch.
First, generate the patch reference base.
```bash 
PS> Update-DbaBuildReference
```
Display current patch level and version
```bash 
PS> Get-DbaBuildReference -SqlInstance $server
SqlInstance    : mssql2025
Build          : 17.0.1000
NameLevel      : 2025
SPLevel        : RTM
CULevel        : 
KBLevel        : 
BuildLevel     : 17.0.1000
SupportedUntil : 1/6/2036 12:00:00 AM
ReleaseDate    : 11/18/2025 12:00:00 AM
MatchType      : Exact
Warning        :
```
Testing and compliance command - the ultimate judge of your configuration
```bash 
PS> Test-DbaBuild -SqlInstance $server -Latest
Build          : 17.0.1000
BuildLevel     : 17.0.1000
BuildTarget    : 17.0.4040
Compliant      : False
CULevel        : 
CUTarget       : 
KBLevel        : 
MatchType      : Exact
MaxBehind      : 
NameLevel      : 2025
ReleaseDate    : 11/18/2025 12:00:00 AM
SPLevel        : RTM
SPTarget       : 
SqlInstance    : mssql2025
SupportedUntil : 1/6/2036 12:00:00 AM
Warning

PS> Test-DbaBuild -SqlInstance $server -MinimumBuild 17.0.4020.2
Build          : 17.0.1000
BuildLevel     : 17.0.1000
Compliant      : False
CULevel        : 
KBLevel        : 
MatchType      : Exact
MinimumBuild   : 17.0.4020.2
NameLevel      : 2025
ReleaseDate    : 11/18/2025 12:00:00 AM
SPLevel        : RTM
SqlInstance    : mssql2025
SupportedUntil : 1/6/2036 12:00:00 AM
Warning        :
```

### Error Log - Quick retrieval of the last few minutes
```bash 
PS > $splatGetErrorLog = @{
        SqlInstance = $server
        After = (Get-Date).AddMinutes(-5)
    }
PS> Get-DbaErrorLog @splatGetErrorLog | Select LogDate, Source, Text
```

### Orphaned users - Ah, one of my favorite commands. 
Every SQL Server DBA has faced orphaned users especially after a cluster failover. This command allows you to check for them.
```bash 
PS> Get-DbaDbOrphanUser -SqlInstance $server -Database $db
PS> Repair-DbaOrphanUser -SqlInstance $server -Database $db
```

### Backups - It’s my go-to for auditing backup retention and ensuring everything is running as scheduled. 
```bash 
PS> Get-DbaBackupInformation -SqlInstance $server -Path /var/opt/mssql/bak -Database tpcc                             
SqlInstance Database Type         TotalSize DeviceType Start                   Duration End                             
----------- -------- ----         --------- ---------- -----                   -------- ---                             
mssql2025   tpcc     Log          846.75 MB Disk       2026-05-12 08:53:00.000 00:00:02 2026-05-12 08:53:02.000         
mssql2025   tpcc     Log          1.46 GB   Disk       2026-05-08 08:35:54.000 00:00:02 2026-05-08 08:35:56.000         
mssql2025   tpcc     Log          115.00 KB Disk       2026-05-08 07:32:17.000 00:00:00 2026-05-08 07:32:17.000         
mssql2025   tpcc     Differential 2.12 MB   Disk       2026-05-08 07:32:10.000 00:00:00 2026-05-08 07:32:10.000         
mssql2025   tpcc     Full         329.12 MB Disk       2026-05-08 07:31:38.000 00:00:01 2026-05-08 07:31:39.000      

PS>  Get-DbaDbBackupHistory -SqlInstance $server -Last
SqlInstance Database Type         TotalSize DeviceType Start                   Duration End
----------- -------- ----         --------- ---------- -----                   -------- ---
mssql2025   AdminDB  Full         19.09 MB  Disk       2026-05-08 07:31:38.000 00:00:00 2026-05-08 07:31:38.000
mssql2025   AdminDB  Differential 2.09 MB   Disk       2026-05-08 07:32:10.000 00:00:00 2026-05-08 07:32:10.000
mssql2025   Contoso  Full         281.09 MB Disk       2026-05-08 07:31:38.000 00:00:00 2026-05-08 07:31:38.000
mssql2025   Contoso  Differential 2.09 MB   Disk       2026-05-08 07:32:10.000 00:00:00 2026-05-08 07:32:10.000
mssql2025   master   Full         4.09 MB   Disk       2026-05-08 07:31:03.000 00:00:01 2026-05-08 07:31:04.000
mssql2025   model    Full         2.96 MB   Disk       2026-05-08 07:31:04.000 00:00:00 2026-05-08 07:31:04.000
mssql2025   msdb     Full         16.09 MB  Disk       2026-05-08 07:31:04.000 00:00:00 2026-05-08 07:31:04.000
```

### Test restore (including certificates remediation)

A new db named dbatools-testrestore-tpcc is created.
```bash 
PS /> Set-DbatoolsConfig -Name 'sql.connection.trustcert' -Value $true      
PS /> $instance = "host.docker.internal,1468"                            
PS /> Test-DbaLastBackup -SqlInstance $instance -SqlCredential $cred -DataDirectory /var/opt/mssql/restore -LogDirectory /var/opt/mssql/restore -Database tpcc -NoDrop
SourceServer   : host.docker.internal,1468                                                                              
TestServer     : host.docker.internal,1468
Database       : tpcc
FileExists     : True
Size           : 2.61 GB
RestoreResult  : Success
DbccResult     : Success
RestoreStart   : 2026-05-12 09:35:43.287
RestoreEnd     : 2026-05-12 09:36:09.859
RestoreElapsed : 00:00:26
DbccMaxDop     : 0
DbccStart      : 2026-05-12 09:36:09.908
DbccEnd        : 2026-05-12 09:36:15.633
DbccElapsed    : 00:00:05
DbccOutput     : {DBCC results for 'dbatools-testrestore-tpcc'., Service Broker Msg 9675, State 1: Message Types analyzed: 14., 
                 Service Broker Msg 9676, State 1: Service Contracts analyzed: 6., Service Broker Msg 9667, State 1: Services 
                 analyzed: 3.…}
BackupDates    : {2026-05-08 07:31:38.000, 2026-05-08 07:32:10.000, 2026-05-08 07:32:17.000, 2026-05-08 08:35:54.000…}
BackupFiles    : {/var/opt/mssql/bak/mssql2025/tpcc/FULL/mssql2025_tpcc_FULL_20260508_073138.bak, 
                 /var/opt/mssql/bak/mssql2025/tpcc/DIFF/mssql2025_tpcc_DIFF_20260508_073210.bak, 
                 /var/opt/mssql/bak/mssql2025/tpcc/LOG/mssql2025_tpcc_LOG_20260508_073217.trn, 
                 /var/opt/mssql/bak/mssql2025/tpcc/LOG/mssql2025_tpcc_LOG_20260508_083553.trn…}
```

### Jobs - Useful for quickly listing jobs and their last execution.
```bash 
PS> Get-DbaAgentJob -SqlInstance $server
ComputerName           : host.docker.internal
InstanceName           : MSSQLSERVER
SqlInstance            : mssql2025
Name                   : CommandLog Cleanup
Category               : Database Maintenance
OwnerLoginName         : sa
CurrentRunStatus       : Idle
CurrentRunRetryAttempt : 0
Enabled                : True
LastRunDate            : 1/1/0001 12:00:00 AM
LastRunOutcome         : Unknown
HasSchedule            : False
OperatorToEmail        : 
CreateDate             : 5/8/2026 7:30:47 AM

ComputerName           : host.docker.internal
InstanceName           : MSSQLSERVER
...
PS> Get-DbaAgentAlert -SqlInstance $server
PS> Find-DbaAgentJob -SqlInstance $server -JobName *DatabaseBackup* | Select SqlInstance, JobName, LastRunDate, LastRunOutcome 
  
SqlInstance JobName                                  LastRunDate          LastRunOutcome
----------- -------                                  -----------          --------------
mssql2025   DatabaseBackup - SYSTEM_DATABASES - FULL 5/8/2026 7:31:02 AM       Succeeded
mssql2025   DatabaseBackup - USER_DATABASES - DIFF   5/8/2026 7:32:09 AM       Succeeded
mssql2025   DatabaseBackup - USER_DATABASES - FULL   5/8/2026 7:31:37 AM       Succeeded
```

### Jobs timeline - Great for getting a clear visual overview.
```bash 
PS> $threeDaysAgo = [datetime]::Today.AddDays(-3)
PS> Find-DbaAgentJob -SqlInstance $server |
Get-DbaAgentJobHistory -StartDate $threeDaysAgo |
ConvertTo-DbaTimeline |
Out-File -FilePath /tmp/jobs.html -Encoding ASCII
```

### PII - I’m sure you’ve been asked this before: 'Do we have credit card data stored in the database?' 

This command isn't a silver bullet, but it can provide some initial answers.
```bash 
PS> Invoke-DbaDbPiiScan -SqlInstance $server -Database tpcc  
                                                                                                                      
ComputerName   : host.docker.internal
InstanceName   : MSSQLSERVER
SqlInstance    : mssql2025
Database       : tpcc
Schema         : dbo
Table          : customer
Column         : c_credit_lim
PII-Category   : Financial
PII-Name       : CreditCard
FoundWith      : KnownName
MaskingType    : Finance
MaskingSubType : CreditcardNumber
Pattern        : {(\w*)(?i)(credit|creditcard)(\w*), (?>cre?di?t_?(ca?rd)?_?(num(ber)?\|nbr\|no)?)(?!\w*ID)}

ComputerName   : host.docker.internal
InstanceName   : MSSQLSERVER
SqlInstance    : mssql2025
Database       : tpcc
Schema         : dbo
Table          : customer
Column         : c_first
PII-Category   : Location
PII-Name       : Zipcode
FoundWith      : Pattern
MaskingType    : Address
MaskingSubType : Zipcode
Country        : United Kingdom
CountryCode    : UK
Pattern        : ([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z
                 ][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})
Description    : 

ComputerName   : host.docker.internal
InstanceName   : MSSQLSERVER
SqlInstance    : mssql2025
Database       : tpcc
Schema         : dbo
Table          : customer
Column         : c_credit
PII-Category   : Financial
PII-Name       : CreditCard
FoundWith      : KnownName
MaskingType    : Finance
MaskingSubType : CreditcardNumber
Pattern        : {(\w*)(?i)(credit|creditcard)(\w*), (?>cre?di?t_?(ca?rd)?_?(num(ber)?\|nbr\|no)?)(?!\w*ID)}

ComputerName   : host.docker.internal
InstanceName   : MSSQLSERVER
SqlInstance    : mssql2025
Database       : tpcc
Schema         : dbo
Table          : customer
Column         : c_street_1
PII-Category   : Location
PII-Name       : Zipcode
FoundWith      : Pattern
MaskingType    : Address
MaskingSubType : Zipcode
Country        : United Kingdom
CountryCode    : UK
Pattern        : ([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z
                 ][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})
Description    : 
```

### DACPAC - Database as Code
Perfect for deploying instances in dev/preprod to ensure the exact same schema configuration everywhere.
```bash 
PS> $splatExportDacPac = @{
  SqlInstance = $server
  Database = "tpcc"
  FilePath = "/tmp/tpcc.dacpac"
}
PS> Export-DbaDacPackage @splatExportDacPac
Export-DbaDacPackage @splatExportDacPac

Database    : tpcc
Elapsed     : 15.41 s
Path        : /tmp/tpcc.dacpac
Result      : Extracting schema (Start)
              Gathering database credentials
              Gathering database options
              Gathering generic database scoped configuration option
              Gathering users
              Gathering roles
              Gathering application roles
              Gathering role memberships
              Gathering filegroups
...

PS> $splatPublishDacPac = @{
  SqlInstance = $server
  Database = "tpccIssueIssue"
  Path     = "/tmp/tpcc.dacpac"
}
PS> Publish-DbaDacPackage @splatPublishDacPac
```

### dbachecks
Installation:
```bash 
PS> Install-Module dbachecks -Scope CurrentUser 
PS> Install-Module Pester -RequiredVersion 4.10.1 -Scope CurrentUser
```

Usage:
Configuration check, backup check.
```bash 
PS> Invoke-DbcCheck -SqlInstance $server -Check LastFullBackup
[09:43:26][Invoke-DbcCheckv4] 
Key        Value
---        -----
ExcludeTag 
Tag        {LastFullBackup}
Script     /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1


Pester v4.10.1
Executing all tests in '/root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1' with Tags LastFullBackup

Executing script /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1

  Describing Last Full Backup Times

    Context Testing last full backups on host.docker.internal,1468
      [+] Database AdminDB should have full backups less than 7 days old on host.docker.internal,1468 2ms
      [+] Database Contoso should have full backups less than 7 days old on host.docker.internal,1468 2ms
      [-] Database master should have full backups less than 7 days old on host.docker.internal,1468 5ms
        Expected the actual value to be greater than 2026-05-12T09:43:26.4077893Z, because Taking regular backups is extraordinarily important, but got 2026-05-08T07:31:04.0000000Z.
        498:                         $psitem.LastBackupDate.ToUniversalTime() | Should -BeGreaterThan (Get-Date).ToUniversalTime().AddDays( - ($maxfull)) -Because "Taking regular backups is extraordinarily important"
        at <ScriptBlock>, /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1: line 498
      [-] Database model should have full backups less than 7 days old on host.docker.internal,1468 7ms
        Expected the actual value to be greater than 2026-05-12T09:43:26.4281548Z, because Taking regular backups is extraordinarily important, but got 2026-05-08T07:31:04.0000000Z.
        498:                         $psitem.LastBackupDate.ToUniversalTime() | Should -BeGreaterThan (Get-Date).ToUniversalTime().AddDays( - ($maxfull)) -Because "Taking regular backups is extraordinarily important"
        at <ScriptBlock>, /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1: line 498
      [-] Database msdb should have full backups less than 7 days old on host.docker.internal,1468 6ms
        Expected the actual value to be greater than 2026-05-12T09:43:26.4450238Z, because Taking regular backups is extraordinarily important, but got 2026-05-08T07:31:04.0000000Z.
        498:                         $psitem.LastBackupDate.ToUniversalTime() | Should -BeGreaterThan (Get-Date).ToUniversalTime().AddDays( - ($maxfull)) -Because "Taking regular backups is extraordinarily important"
        at <ScriptBlock>, /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1: line 498
      [+] Database tpcc should have full backups less than 7 days old on host.docker.internal,1468 3ms
Tests completed in 249ms
Tests Passed: 3, Failed: 3, Skipped: 0, Pending: 0, Inconclusive: 0

PS> Invoke-DbcCheck -SqlInstance $server -Check LastGoodCheckDb, MaxMemory
[09:45:54][Invoke-DbcCheckv4] 
Key        Value
---        -----
ExcludeTag 
Tag        {LastGoodCheckDb, MaxMemory}
Script     {/root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1, /root/.local/share/powershell/Modules/db…


Pester v4.10.1
Executing all tests in '/root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1', '/root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Instance.Tests.ps1' with Tags LastGoodCheckDb', 'MaxMemory

Executing script /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1

  Describing Last Good DBCC CHECKDB

    Context Testing Last Good DBCC CHECKDB on host.docker.internal,1468
      [+] Database master last good integrity check should be less than 7 days old on mssql2025 5ms
      [+] Database master has Data Purity Enabled on mssql2025 6ms
      [+] Database model last good integrity check should be less than 7 days old on mssql2025 2ms
      [+] Database model has Data Purity Enabled on mssql2025 2ms
      [+] Database msdb last good integrity check should be less than 7 days old on mssql2025 2ms
      [+] Database msdb has Data Purity Enabled on mssql2025 14ms
      [+] Database Contoso last good integrity check should be less than 7 days old on mssql2025 3ms
      [+] Database Contoso has Data Purity Enabled on mssql2025 1ms
      [+] Database tpcc last good integrity check should be less than 7 days old on mssql2025 1ms
      [+] Database tpcc has Data Purity Enabled on mssql2025 2ms
      [+] Database AdminDB last good integrity check should be less than 7 days old on mssql2025 2ms
      [+] Database AdminDB has Data Purity Enabled on mssql2025 2ms

Executing script /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Instance.Tests.ps1

  Describing Max Memory

    Context Testing Max Memory on host.docker.internal,1468
      [-] Max Memory setting should be correct (running on Linux so only checking Max Memory is less than Total Memory) on host.docker.internal,1468 64ms
        Expected the actual value to be greater than 2147483647, because You do not want to exhaust server memory, but got 11853.
        285:                         $MemoryValues.Total | Should -BeGreaterThan $MemoryValues.MaxValue -Because 'You do not want to exhaust server memory'
        at <ScriptBlock>, /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Instance.Tests.ps1: line 285
Tests completed in 1.87s
Tests Passed: 12, Failed: 1, Skipped: 0, Pending: 0, Inconclusive: 0
```
