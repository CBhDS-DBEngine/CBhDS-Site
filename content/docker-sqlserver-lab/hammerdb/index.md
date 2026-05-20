---
title: "HammerDB in Docker"
date: 2026-05-18
summary: "Deploy HammerDB in a Docker container and simulate workload against a SQL Server instance"
---

This article covers the following steps:

- Deploy a dedicated container for HammerDB, the industry standard open-source database benchmark tool
  
- Create a new TPC-C database on an existing SQL instance in a separate container
  
- Create a SQL Server workload scenario
  
- Execute workload simulations



1/ Install HammerDB on Windows
```bash
PS> docker pull tpcorg/hammerdb:mssqls
PS> docker tag tpcorg/hammerdb:mssqls hammerdb:mssqls
```
2/ Run the image in a container

3/ Update and configuration to build the tpcc db

3a/ Execute these commands in the container

/tmp is necessary to build the schema
```bash
# apt-get update
# mkdir -p /tmp
# export TMP=/tmp
```
3b/ Configure Schema Build

In my configuration, the SQL Server instance runs in another container named mssql2025 and the port is 1468. 

Authentication: SQL Server using sa login.

I do not want to manage docker subnet, so I use the "host.docker.internal" feature to interconnect the SQL Server container and the HammerDB one.
```bash
#./hammerdbcli
hammerdb>dbset db mssqls
hammerdb>dbset bm TPROC-C
hammerdb>diset connection mssqls_server mssql2025
hammerdb>diset connection mssqls_port 1468
hammerdb>diset connection mssqls_uid sa
hammerdb>diset connection mssqls_pass "SA_PASSWORD"
hammerdb>diset connection mssqls_server host.docker.internal
hammerdb>diset connection mssqls_linux_server host.docker.internal
hammerdb>diset connection mssqls_authentication sql
hammerdb>diset connection mssqls_tcp true
```
I had issues with bcp execution, especially with the u/U paraameters. I decide to not use bcp. The build is longer to run but successful.
```bash
hammerdb>diset tpcc mssqls_use_bcp false
```
Finally, here the configuration :
```bash
hammerdb>print dict
Dictionary Settings for MSSQLServer
connection {
 mssqls_server             = host.docker.internal
 mssqls_linux_server       = host.docker.internal
 mssqls_tcp                = true
 mssqls_port               = 1468
 mssqls_azure              = false
 mssqls_authentication     = sql
 mssqls_msi_object_id      = null
 mssqls_linux_authent      = sql
 mssqls_odbc_driver        = ODBC Driver 18 for SQL Server
 mssqls_linux_odbc         = ODBC Driver 18 for SQL Server
 mssqls_uid                = sa
 mssqls_pass               = SA_PASSWORD
 mssqls_encrypt_connection = true
 mssqls_trust_server_cert  = true
```
4/ Build schema

It creates a tpcc db in the SQL server instance. It can take a while ...
```bash 
ammerdb>buildschema
Script cleared
Building 1 Warehouses(s) with 1 Virtual User
....
```
 
5/ Generate transactions 

Depending of your needs, you can change teh follwong parameters. On my side i do use 1 warehouse, and 15 users.

I'm able to generate running, runnable, waiting sessions and locks. 

5a/ Prepare the run 
```bash
hammerdb> diset tpcc mssqls_rampup 1
hammerdb> diset tpcc mssqls_duration 2
hammerdb> vuset showoutput 1
hammerdb> vuset vu 15
hammerdb> vucreate
```
5b/ Run
```bash
hammerdb> vurun
```
5c/ Clear
```bash
hammerdb> vudestroy
```


