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
