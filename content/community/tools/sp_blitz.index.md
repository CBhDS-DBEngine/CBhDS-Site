---
title: "First Responder Kit in Practice"
summary: "Troubleshooting and resolving issues in real-time with sp_blitz."
---
Keep in mind that sp_BlitzFirst runs for 5 seconds by default. You can increase this duration using the @Seconds parameter."


## Live Health Check

I use sp_BlitzFirst for real-time troubleshooting as soon as a user reports a slowdown.
```bash 
EXEC sp_BlitzFirst
```
<img width="1323" height="188" alt="SSMS-260521-123651" src="https://github.com/user-attachments/assets/99e28815-eaec-4260-9a71-f44650dbdbe6" />


The 'Blocking Detected' alert identifies the lead blocker. Often, this lead blocker is a 'Sleeping Session.' This is a typical scenario where an application opens a transaction and modifies data but fails to close the connection (missing a COMMIT or ROLLBACK).

Quite often, the 'Lead Blocker' is a Sleeping Session. This is a classic example of an application that has opened a transaction and modified data, but then 'forgotten' to close the connection (no COMMIT or ROLLBACK). The session is essentially doing 'nothing' (it is sleeping), yet it continues to hold onto its locks.

```bash
EXEC sp_BlitzFirst @ShowSleepingSPIDs = 1
```

The Expert Mode provides much more detail by automatically executing sp_BlitzWho alongside the main check (Detailed Wait Stats).
```bash 
EXEC sp_BlitzFirst @ExpertMode = 1;
```

<img width="1091" height="585" alt="image" src="https://github.com/user-attachments/assets/c0e968c3-d9c1-42b4-be0a-f258960dd119" />
