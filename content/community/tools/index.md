---
title: "Community ressources for SQL Server"
date: 2026-05-07
summary: "List some important community ressources for SQL Server I use for many years"
---

Here are some of my favorite community resources that I’ve used for many years. A second article will showcase concrete use cases.

I tried to organize them by category.

## ANALYSYS & PERFORMANCE TUNING

### First Responder Kit by Brent Ozar Unlimited : https://www.brentozar.com/ - Open-source T-SQL script collection.

In the world of SQL Server performance tuning, these two scripts are often the first reflex for any DBA or Developer facing a slow server.

- **sp_BlitzFirst**: Think of this as an EKG for your database. It looks at what is happening **right now**. I use it in conjunction with **sp_WhoIsActive** (see below).
- **sp_Blitz**: The next natural step to check the entire configuration.

Remaining scripts :

- sp_BlitzCache: Find the Most Resource-Intensive Queries
- sp_BlitzIndex: Tune Your Indexes
- sp_BlitzWho: What Queries are Running Now
- sp_BlitzLock: Deadlock Analysis
- sp_kill: Emergency Session Killer
- sp_DatabaseRestore: Easier Multi-File Restores if you use Ola Hallengren's backup scripts

### sp_WhoIsActive by Adam Machanic - http://whoisactive.com/ - T-SQL (Transact-SQL)

**sp_WhoIsActive ** is query-centric. It allows you to zoom in on every active session to see precisely what it's doing, how much resource it's consuming, and why it's slow. This tool provides *granular, real-time visibility*allowing you to drill down into specific problems using its many advanced options.


While my first reflex is to check the server-wide health, my second reflex is query-centric. I use sp_WhoIsActive to zoom in on active sessions...

Automatisation & DevOps SQL Server
**********************************

dbatools : Ok
	https://dbatools.io/, 700+ powershell tools : Ok
	Livre : Learn dbatools in a Month of Lunches : Ok
	

## PREVENTIVE MAINTENANCE

### DatabaseBackup, Database IntegrityCheck, 
No introduction is needed for Ola Hallengren’s Maintenance Solution; it is the industry standard for backups, integrity checks, and index optimization."
https://ola.hallengren.com/
	DatabaseBackup, DatabaseIntegrityCheck, IndexOptimize, CommandExecute

Monitoring
**********

DBA Dash
	Monitoring + checks + tracking de config

SQLWATCH 
	Nécessite Tableau / Power BI

Tunning
*******

SentryOne Plan Explorer
	https://www.solarwinds.com/free-tools/plan-explorer

SQLQueryStress
	Tester une requête sous charge
	Comparer les performances avant/après tuning

Statistic Parser (Richie Rump)


Test unitaire
*************

tSQLt
	Framework de tests unitaires 

Generic
*******

Azure Data Studio (ADS)
	Azure Data Studio est un éditeur SQL moderne, multiplateforme (Windows, Linux, macOS), 
	extensible, pensé pour l’analyse, le développement et l’observabilité SQL Server.
	+ SQL Server Assessment


Livres
******

Microsoft Azure Essentials Migrating Sql Server Databases To Azure
Ok : Learn dbatools in a Month of Lunches
