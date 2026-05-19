---
title: "Community ressources for SQL Server"
date: 2026-05-07
summary: "List some important community ressources for SQL Server "
---

Here are some of my favorite community resources that I’ve used for many years. 

I tried to organize them by category.

1/ ANALYSYS & PERFORMANCE TUNING

First Responder Kit by Brent Ozar Unlimited : https://www.brentozar.com/ - Open-source T-SQL script collection.

- sp_BlitzFirst --> Real-Time Performance Advice / Troubleshoot Slow SQL Server
- sp_Blitz –-> Overall Health Check
- sp_BlitzCache --> Find the Most Resource-Intensive Queries
- sp_BlitzIndex –-> Tune Your Indexes
- sp_BlitzWho --> What Queries are Running Now
- sp_BlitzLock --> Deadlock Analysis
- sp_kill --> Emergency Session Killer
-  sp_DatabaseRestore --> Easier Multi-File Restores if you use Ola Hallengren's backup scripts

sp_WhoIsActive de Adam Machanic → problème en cours
	http://whoisactive.com/
	T-SQL (Transact-SQL)

Glenn Berry Diagnostic Queries
	Ensemble de scripts T-SQL conçus pour surveiller et diagnostiquer les 
	performances de Microsoft SQL Server.
	https://glennsqlperformance.com/home/

Tiger Toolbox
	https://github.com/microsoft/tigertoolbox
	Tiger team of MS


Automatisation & DevOps SQL Server
**********************************

dbatools : Ok
	https://dbatools.io/, 700+ powershell tools : Ok
	Livre : Learn dbatools in a Month of Lunches : Ok
	
Ansible
	Ansible est un excellent choix si tu veux automatiser la gestion, 
	le déploiement, la configuration et l’audit de SQL Server
	S'intègre avec dbatools, OLA ...
	
Terraform 
	Déclarer et provisionner l’infrastructure, tandis qu’Ansible configure et maintient.
 
 
| Besoin 					| Terraform 		| Ansible 		| dbatools
| Provisionner VM / réseau  | ⭐ Oui 			| ✔ Possible 	| ❌ Non 
| Installer SQL Server 		| ⚠️ Non (pas seul) | ⭐ Oui 		| ✔ Oui 
| Configurer SQL Server 	| ❌ Non 			| ⭐ Oui 		| ⭐ Oui
| Déployer scripts SQL 		| ❌ Non 			| ⭐ Oui 		| ⭐ Oui 
| Gérer SQL Azure 			| ⭐ Oui 			| ✔ Possible 	| ❌ Non
| Idéal pour 				| Infra 			| Config 		| SQL pur 

Maintenance
***********

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
