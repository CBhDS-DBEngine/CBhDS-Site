---
title: "Community ressources for SQL Server"
date: 2026-05-07
summary: "List some important community ressources for SQL Server I use for many years"
---

Here are some of my favorite community resources that I’ve used for many years. A second article will showcase concrete use cases.

I tried to organize them by category.

## ANALYSYS & PERFORMANCE TUNING

### 1/ First Responder Kit by Brent Ozar Unlimited : https://www.brentozar.com/ - Open-source T-SQL script collection.

In the world of SQL Server performance tuning, these two scripts are often the first reflex for any DBA or Developer facing a slow server.

- ***sp_BlitzFirst***: Think of this as an EKG for your database. It looks at what is happening **right now**. I use it in conjunction with ***sp_WhoIsActive*** (see below).
- ***sp_BlitzCache***: Find the Most Resource-Intensive Queries
- ***sp_Blitz***: The next natural step to check the entire configuration.

Remaining scripts :

- *sp_BlitzIndex*: Tune Your Indexes
- *sp_BlitzWho*: What Queries are Running Now
- *sp_BlitzLock*: Deadlock Analysis
- *sp_kill*: Emergency Session Killer
- *sp_DatabaseRestore*: Easier Multi-File Restores if you use Ola Hallengren's backup scripts

### 2/ sp_WhoIsActive by Adam Machanic - http://whoisactive.com/ - T-SQL (Transact-SQL)

***sp_WhoIsActive*** is query-centric. It allows you to zoom in on every active session to see precisely what it's doing, how much resource it's consuming, and why it's slow. This tool provides *granular, real-time visibility*allowing you to drill down into specific problems using its many advanced options.

`While my first reflex is to check the server-wide health ***sp_BlitzFirst***, my second reflex is query-centric. I use ***sp_WhoIsActive*** to zoom in on active sessions...`

## PREVENTIVE MAINTENANCE

### 1/ SQL Server Backup, Integrity Check, Index & Statistics Maintenance - https://ola.hallengren.com/ - T-SQL (Transact-SQL)

No introduction is needed for Ola Hallengren’s Maintenance Solution; it is the industry standard for backups, integrity checks, and index optimization. 

- *DatabaseBackup*: SQL Server Backup
- *DatabaseIntegrityCheck*: SQL Server Integrity Check
- *IndexOptimize*: SQL Server Index and Statistics Maintenance

If ***sp_Blitz*** warns you about high fragmentation or missing backups, probably Ola Hallengren’s Maintenance Solution is the best way
l help you to solve these issues.

`I particularly like ***@Directory = NULL*** parameter in ***DatabaseBackup***. This is incredibly useful in Always On configurations where databases are in Full Recovery Model. It allows you to perform log backups to truncate the transaction log and prevent 'Log Full' errors, without actually generating unnecessary backup files that consume storage.`


## AUTOMATION AND DevOps SQL SERVER


### dbatools : Ok
	https://dbatools.io/, 700+ powershell tools : Ok
	Livre : Learn dbatools in a Month of Lunches : Ok





