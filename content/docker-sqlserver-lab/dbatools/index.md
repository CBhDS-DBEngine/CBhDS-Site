---
title: "dbatools (including dbachecks) in Docker"
summary: "Deploy dbatools in a dedicated Docker container to connect to SQL Server"
---

This article covers the following steps:

- Start from a PowerShell image
  
- Install dbatools

- Connect to SQL Server

- A couple of examples


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

### 4/ Quick check

Db list:
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

Find practical examples and usage scenarios here: https://cbhds-dbengine.github.io/CBhDS-Site/community/tools/dbatools/
