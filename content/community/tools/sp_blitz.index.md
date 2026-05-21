---
title: "First Responder Kit & sp_WhoIsActive in Practice"
summary: "Troubleshooting and resolving issues in real-time with sp_blitz & sp_WhoIsActive"
---
Keep in mind that sp_BlitzFirst runs for 5 seconds by default. You can increase this duration using the @Seconds parameter."


## Live Health Check

I use sp_BlitzFirst for real-time troubleshooting as soon as a user reports a slowdown.
```bash 
EXEC sp_BlitzFirst
```
<img width="1323" height="188" alt="SSMS-260521-123651" src="https://github.com/user-attachments/assets/99e28815-eaec-4260-9a71-f44650dbdbe6" />

Often, this lead blocker is a 'Sleeping Session.' This is a typical scenario where an application opens a transaction and modifies data but fails to close the connection (missing a COMMIT or ROLLBACK).

Quite often, the 'Lead Blocker' is a Sleeping Session. This is a classic example of an application that has opened a transaction and modified data, but then 'forgotten' to close the connection (no COMMIT or ROLLBACK). The session is essentially doing 'nothing' (it is sleeping), yet it continues to hold onto its locks.

```bash
EXEC sp_BlitzFirst @ShowSleepingSPIDs = 1
```

The Expert Mode provides much more detail by automatically executing sp_BlitzWho alongside the main check (Detailed Wait Stats).
```bash 
EXEC sp_BlitzFirst @ExpertMode = 1;
```

<img width="1091" height="585" alt="image" src="https://github.com/user-attachments/assets/c0e968c3-d9c1-42b4-be0a-f258960dd119" />  


## Post-mortem analysis and proactive tuning
While sp_BlitzFirst tells you what's happening right now, sp_BlitzCache looks at the "memory" of your SQL Server (the Plan Cache) to show you which queries have been the most problematic since the last restart or cache clear.

```bash
EXEC sp_BlitzCache
```

<img width="1140" height="529" alt="image" src="https://github.com/user-attachments/assets/eb387464-6b4b-4aed-b398-10a7a30f6fdc" />


The *@SortOrder* parameter is used to change how sp_BlitzCache prioritises the results. It helps you focus on the specific type of resource pressure your server is experiencing.

For instance, if the server is experiencing high processor usage, run the check sorted by CPU: *EXEC sp_BlitzCache @SortOrder = 'cpu';*
If you are seeing high 'Page I/O' waits, it is better to sort by reads to find the queries scanning the largest tables: *EXEC sp_BlitzCache @SortOrder = 'reads';*

```bash
EXEC sp_BlitzCache @SortOrder = 'cpu';
```

## Analysis Since Last Restart
If you want to investigate performance issues that have occurred since the server was last booted—rather than just a real-time snapshot—use the @SinceStartup parameter:
```bash 
EXEC sp_BlitzFirst @SinceStartup = 1;
```
<img width="1099" height="576" alt="image" src="https://github.com/user-attachments/assets/8f711488-882d-402d-80f1-3d547514cafd" />

