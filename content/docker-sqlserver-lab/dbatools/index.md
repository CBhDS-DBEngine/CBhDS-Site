---
title: "dbatools (including dbachecks) in Docker"
summary: "Deploy dbatools in a dedicated Docker container to connect to SQL Server"
---

This article covers the following steps:

- Start from a PowerShell image
  
- Install dbatools

- Connect to SQL Server

- A quick check


## 1/ PowerShell Image


```bash 
CMD> docker run -id --name dbatools mcr.microsoft.com/powershell:lts-ubuntu-22.04 pwsh
```

## 2/ dbatools installation 

To execute on the container:
```bash 
#> pwsh
PS> Install-Module -Name dbatools -Force -AllowClobber -Scope CurrentUser
```
Verification :
```bash 
PS> Get-Command -Module dbatools -Name Connect-DbaInstance
```

## 3/ Connection passphrase.

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

## 3/ dbacheck installation:
```bash 
PS> Install-Module dbachecks -Scope CurrentUser 
PS> Install-Module Pester -RequiredVersion 4.10.1 -Scope CurrentUser
```

### 4/ Quick check

dbatools:
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
DbcCheck:
```bash 
PS> Invoke-DbcCheck -SqlInstance $server -Check LastFullBackup -Verbose
VERBOSE: [12:09:04][Invoke-DbcCheck] Running in legacy mode, we need Version 4
VERBOSE: [12:09:04][Invoke-DbcCheck] import Version 4
VERBOSE: Loading module from path '/root/.local/share/powershell/Modules/Pester/4.10.1/Pester.psd1'.
VERBOSE: Loading 'TypesToProcess' from path '/root/.local/share/powershell/Modules/Pester/4.10.1/Functions/Gherkin.types.ps1xml'.
VERBOSE: Populating RepositorySourceLocation property for module Pester.
VERBOSE: Loading module from path '/root/.local/share/powershell/Modules/Pester/4.10.1/Pester.psm1'.
VERBOSE: Importing function 'Add-AssertionOperator'.
VERBOSE: Importing function 'AfterAll'.
VERBOSE: Importing function 'AfterEach'.
VERBOSE: Importing function 'AfterEachFeature'.
VERBOSE: Importing function 'AfterEachScenario'.
VERBOSE: Importing function 'Assert-MockCalled'.
VERBOSE: Importing function 'Assert-VerifiableMock'.
VERBOSE: Importing function 'Assert-VerifiableMocks'.
VERBOSE: Importing function 'BeforeAll'.
VERBOSE: Importing function 'BeforeEach'.
VERBOSE: Importing function 'BeforeEachFeature'.
VERBOSE: Importing function 'BeforeEachScenario'.
VERBOSE: Importing function 'Context'.
VERBOSE: Importing function 'Describe'.
VERBOSE: Importing function 'Find-GherkinStep'.
VERBOSE: Importing function 'Get-MockDynamicParameter'.
VERBOSE: Importing function 'Get-ShouldOperator'.
VERBOSE: Importing function 'Get-TestDriveItem'.
VERBOSE: Importing function 'GherkinStep'.
VERBOSE: Importing function 'In'.
VERBOSE: Importing function 'InModuleScope'.
VERBOSE: Importing function 'Invoke-Gherkin'.
VERBOSE: Importing function 'Invoke-Mock'.
VERBOSE: Importing function 'Invoke-Pester'.
VERBOSE: Importing function 'It'.
VERBOSE: Importing function 'Mock'.
VERBOSE: Importing function 'New-Fixture'.
VERBOSE: Importing function 'New-MockObject'.
VERBOSE: Importing function 'New-PesterOption'.
VERBOSE: Importing function 'SafeGetCommand'.
VERBOSE: Importing function 'Set-DynamicParameterVariable'.
VERBOSE: Importing function 'Set-ItResult'.
VERBOSE: Importing function 'Set-TestInconclusive'.
VERBOSE: Importing function 'Setup'.
VERBOSE: Importing function 'Should'.
VERBOSE: Importing alias 'Add-ShouldOperator'.
VERBOSE: Importing alias 'And'.
VERBOSE: Importing alias 'But'.
VERBOSE: Importing alias 'Given'.
VERBOSE: Importing alias 'Then'.
VERBOSE: Importing alias 'When'.
[12:09:05][Invoke-DbcCheckv4] 
Key        Value
---        -----
ExcludeTag 
Tag        {LastFullBackup}
Verbose    True
Script     /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1


Pester v4.10.1
Executing all tests in '/root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1' with Tags LastFullBackup

Executing script /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1

  Describing Last Full Backup Times

    Context Testing last full backups on host.docker.internal,1468
      [+] Database AdminDB should have full backups less than 7 days old on host.docker.internal,1468 27ms
      [+] Database Contoso should have full backups less than 7 days old on host.docker.internal,1468 2ms
      [-] Database master should have full backups less than 7 days old on host.docker.internal,1468 25ms
        Expected the actual value to be greater than 2026-05-13T12:09:06.0408326Z, because Taking regular backups is extraordinarily important, but got 2026-05-08T07:31:04.0000000Z.
        498:                         $psitem.LastBackupDate.ToUniversalTime() | Should -BeGreaterThan (Get-Date).ToUniversalTime().AddDays( - ($maxfull)) -Because "Taking regular backups is extraordinarily important"
        at <ScriptBlock>, /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1: line 498
      [-] Database model should have full backups less than 7 days old on host.docker.internal,1468 4ms
        Expected the actual value to be greater than 2026-05-13T12:09:06.0933417Z, because Taking regular backups is extraordinarily important, but got 2026-05-08T07:31:04.0000000Z.
        498:                         $psitem.LastBackupDate.ToUniversalTime() | Should -BeGreaterThan (Get-Date).ToUniversalTime().AddDays( - ($maxfull)) -Because "Taking regular backups is extraordinarily important"
        at <ScriptBlock>, /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1: line 498
      [-] Database msdb should have full backups less than 7 days old on host.docker.internal,1468 5ms
        Expected the actual value to be greater than 2026-05-13T12:09:06.1062036Z, because Taking regular backups is extraordinarily important, but got 2026-05-08T07:31:04.0000000Z.
        498:                         $psitem.LastBackupDate.ToUniversalTime() | Should -BeGreaterThan (Get-Date).ToUniversalTime().AddDays( - ($maxfull)) -Because "Taking regular backups is extraordinarily important"
        at <ScriptBlock>, /root/.local/share/powershell/Modules/dbachecks/3.0.2/checks/Database.Tests.ps1: line 498
      [+] Database tpcc should have full backups less than 7 days old on host.docker.internal,1468 2ms
Tests completed in 493ms
Tests Passed: 3, Failed: 3, Skipped: 0, Pending: 0, Inconclusive: 0 

```


`Find practical examples and usage scenarios here: https://cbhds-dbengine.github.io/CBhDS-Site/community/tools/dbatools/`
