---
title: "SQL Server Always On Cluster with a Simulated Witness in Docker"
summary: "Setting Up a SQL Server Always On Cluster with a Simulated Witness in Docker"
categories: ["Docker"]
tags: [
  "SQL Server 2025", 
  "Always On Availability Groups", 
  "Clusterless AG", 
  "Database Automation", 
  "High Availability", 
  "Failover Testing", 
  "DevOps", 
  "MSSQL Linux"
]
---

This article covers the following steps:

- Building a SQL Server 2025 image for a 2-node Always On cluster
- Building a witness node
- Building of a witness
- Failover exercices


## 1/ Features & Functionality

- **2-node Always On cluster** using the latest SQL Server 2025 provided by Microsoft.
- **Database restoration** of your choice via a full backup.
- **Availability Group (AG) creation** and synchronization of the restored database across both nodes.
- **A lightweight witness container** based on the `sqlcmd` tools image, capable of detecting node outages and triggering a failover if the primary node goes down.

## 2/ References & Extras

Community references

- Availability Groups with Docker Containers by rafaelrodrigues, https://www.sqlservercentral.com/articles/availability-groups-with-docker-containers
- How to Set Up a SQL Server Always On Environment Using Docker Containers by Yvonne Vanslageren, https://www.sqltabletalk.com/?p=401

Microsoft references

- Microsoft SQL Server - Ubuntu based images, https://hub.docker.com/r/microsoft/mssql-server
- Create and configure an availability group for SQL Server on Linux, https://learn.microsoft.com/en-us/sql/linux/business-continuity/availability-groups/create?view=sql-server-ver17&tabs=ru
- Perform a planned manual failover of an Always On availability group (SQL Server), https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/perform-a-planned-manual-failover-of-an-availability-group-sql-server?view=sql-server-ver17

Additions

On my end, I added a lot of hardening while changing the project's architecture. I'm relying on the existence of objects or services to continue operations, and the SQL Server services are run under mssql...
On the other hand, I added the ability to restore one's own database, as well as that famous "mock" witness.

## 3/ Limitations

- Clusterless Architecture: It is obviously impossible to deploy WSFC (Windows Server Failover Clustering) or its Linux equivalent, Pacemaker & Corosync, inside standard Docker containers. Therefore, this setup is considered a "clusterless" Always On availability group.
It's the reason the Availability Group must be created with `CLUSTER_TYPE = NONE` and `FAILOVER_MODE = MANUAL`.
- Data Loss Risks during Failover: As a consequence, performing a failover requires using the `FORCE_FAILOVER_ALLOW_DATA_LOSS` command, which forces the removal of the old primary node from the availability group.
- Rebuilding Nodes: From an Availability Group (AG) perspective, the old primary node will need to be completely rebuilt after a failover.
- No SSMS for Failover: SQL Server Management Studio (SSMS) is not used to manage the failover due to the Docker environment constraints and to avoid altering any network or security configurations on the host Windows machine.
- Access to the instances by SSMS using "localhost,2500" for node1 and "localhost,2600" for node2.

## 4/ Environment

### Folders and files

The root directory alwayson includes the following files and folders:

```text
── 📂 alwayson         
    ├── 📂 seed-backups      
    │   └── 📄 tpcc_seed.bak        # Initial Full backup of a tpcc database (in full recovery model)
    ├── 🗄️ alwayson_primary.sql   # Configuration / Data for the primary replica
    ├── 🗄️ alwayson_secondary.sql # Configuration / Data for the secondary replica
    ├── 📜 db-init.sh            # T-SQL initialization scripts
    ├── 🐳 docker-compose.yml     # Container orchestration (networks, dependencies, volumes)
    ├── 📄 dockerfile             # Custom SQL Server image
    ├── ⚙️ entrypoint.sh          # Container startup initialization script
    └── 🧠 witness.sh             # Logic / Monitoring script for the simulated witness
```

### Processing

```text
🏁 START: docker-compose up
└── 📦 1. dockerfile (Build Phase)
    └── ⚙️ 2. entrypoint.sh (Container Boot)
        └── 📜 3. db-init.sh (Background Trigger) Initialization Script
            ├── 🗄️ 4a. alwayson_primary.sql   ──┐ (Executed based on
            ├── 🗄️ 4b. alwayson_secondary.sql ──┤  replica identity)
            │   └── 📂 seed-backups/          ──┘ (Restored on secondary)
            └── 🧠 5. witness.sh (Continuous Monitoring)

```
### Files review

*docker-compose.yml* [docker-compose.yml](CBhDS-Site/alwayson/docker-compose.yml)

- Both database nodes (`mssqlaagnode1` and `mssqlaagnode2`), allowing embedded configuration files and automation scripts.
- The cluster uses specialized entry scripts via the `INIT_SCRIPT` environment variable—running `alwayson_primary.sql` on Node 1 and `alwayson_secondary.sql` on Node 2 to automate the Availability Group setup.
- Both SQL Server containers enforce a hard limit of 2048 MB (`MSSQL_MEMORY_LIMIT_MB`). This ensures predictable performance and cluster alignment, as SQL Server checks memory configurations at startup.
- To prevent conflicts on the host machine, Node 1 maps container port `1433` to host port `2500`, while Node 2 maps it to port `2600`.
- Strategic Volume Mapping:
  - A host bind-mount maps local SQL backups (`seed-backups`) into the containers for the initial database restoration.
  - A named volume (`alwayson_shared`) is shared between both nodes to exchange the database mirroring certificates required for the Always On endpoints.
- Both SQL Server containers feature a `sqlcmd` healthcheck that validates SQL engine availability before allowing dependent services to act.
- One lightweight Simulated Witness (`aag-witness`). Instead of a full Windows Server or SQL Server instance, a lightweight `mssql-tools` container runs a custom `witness.sh` bash script. It explicitly waits for both database nodes to start (`depends_on`) and runs continuously (`restart: always`) to monitor health and handle manual failover logic.

*dockerfile* [dockerfile](CBhDS-Site/alwayson/dockerfile)
- Uses the latest official Microsoft SQL Server 2025 image running on an Ubuntu 22.04 base.
- Temporarily switches to `USER root` to install the latest native client tools (`mssql-tools18` and `unixodbc-dev`) required for running the healthcheck and executing internal T-SQL initialization scripts.
- Copies the local automation files into the container and explicitly grants execution permissions.
- Pre-configures the SQL Server engine using `mssql-conf` to permanently enable both the SQL Server Agent and High Availability, which are absolute prerequisites for Always On.
- Creates specific internal directories (`/shared` and `/backup`), ownership is transferred to the `mssql` user, and the default backup path is remapped to match. This ensures secure certificate swapping and database seeding.
- Switches back to the non-privileged `USER mssql` at the end of the build to ensure the container never runs as root.
- Points to a custom `/entrypoint.sh` to orchestrate the sequential startup of the SQL engine alongside the cluster setup scripts.

*db-init.sh* [db-init.sh](CBhDS-Site/alwayson/db-init.sh)

- The script immediately exits if any subsequent command fails, preventing partial or corrupt cluster initializations.
- It maps the environment variable `INIT_SCRIPT` to dynamically execute different SQL scripts (`alwayson_primary.sql` vs. `alwayson_secondary.sql`) depending on the node's designated role.
- The script proactively deletes any pre-existing certificates on PRIMARY (`alwayson_certificate.key`/`.cert`) from the shared volume. This prevents deployment failures if the Docker containers are restarted without deleting the persistent volumes.
- Executes the setup.
        
*alwayson_primary.sql* [alwayson_primary.sql](CBhDS-Site/alwayson/alwayson_primary.sql)

- Restores the template database (`tpcc`) directly into `RECOVERY` mode using a full backup (`.bak`) file mapped from the host Windows machine.
- Creates a dedicated SQL login and a Master Key to secure the Always On environment.
- Generates a custom database mirroring certificate and exports both the certificate and its private key directly into the `/shared` Docker volume so the secondary node can access them.
- Sets up a High Availability and Disaster Recovery (HADR) endpoint on the standard port `5022`.
- Explicitly instantiates the Availability Group with `CLUSTER_TYPE = NONE` and `FAILOVER_MODE = MANUAL`. This allows the Always On group to run inside isolated Docker containers without relying on a traditional cluster manager (like WSFC or Pacemaker).
- Both `mssqlaagnode1` and `mssqlaagnode2` replicas are configured with `SYNCHRONOUS_COMMIT` for zero data loss and `SEEDING_MODE = AUTOMATIC`, meaning SQL Server will automatically stream and create the database on the secondary node over the network.
- Includes an error-handling loop that attempts to add the database to the Availability Group for up to 2.5 minutes (30 retries with a 5-second delay). This ensures the AG setup doesn't fail if the underlying network or endpoint routing takes a few seconds to warm up inside Docker.

*alwayson_secondary.sql* [alwayson_secondary.sql](CBhDS-Site/alwayson/alwayson_secondary.sql)

- Unlike the primary node, the secondary node restores the `tpcc` database backup utilizing the `NORECOVERY` state. This leaves the database unrecovered and open to safely receiving transaction log streams from the primary instance.
- Re-creates the identical login and database Master Key setup. This ensures that the credentials and encryption capabilities perfectly mirror the primary node.
- Includes a T-SQL synchronization loop using `sys.dm_os_file_exists`. Because both containers spin up simultaneously, the secondary node explicitly pauses and checks the `/shared` volume every 10 seconds until it detects that the primary node has finished writing the encryption certificate and private key files.
- Once detected, it securely imports the `alwayson_certificate` directly from the shared volume files, decrypting the private key using the matching cluster password.
- Deploys a mirror HADR endpoint on port `5022`, establishing the secure handshake mechanism for cross-container replication.
- Executes the `JOIN WITH (CLUSTER_TYPE = NONE)` command to bind itself to the clusterless availability group. 
- Grants the availability group permission to `CREATE ANY DATABASE`. This tells SQL Server that it has explicit permission to automatically instantiate, allocate, and synchronize the target replica database behind the scenes without manual DBA intervention.

*witness.sh* [witness.sh](CBhDS-Site/alwayson/witness.sh)

- Enforces script safety by immediately exiting on any command failures, uninitialized variables, or pipelined errors.
- Utilizes an `until` loop to verify that both SQL Server containers are completely initialized and accepting query requests before entering the main loop.
- Implements an infinite `while true` loop running every 10 seconds to dynamically probe the infrastructure status via standard `sqlcmd` commands.
- Split-Brain Guarding:
  - When both nodes are active, it queries `sys.dm_hadr_availability_replica_states` to inspect individual AG roles.
  -If it catches an anomaly where both instances claim to be `PRIMARY` simultaneously, it logs a critical *Potential Split Brain* alert without taking destructive actions.
- Automated Clusterless Failover: 
  - If **Node 1 goes DOWN** and **Node 2 is UP**, it checks if Node 2 needs to take over.
  - If so, it executes `FORCE_FAILOVER_ALLOW_DATA_LOSS` on Node 2 to override the clusterless manual constraint.
  - It then immediately issues a `REMOVE REPLICA` command to isolate the dead primary node from Node 2's configuration.
- Post-Failover Node Cleanup: If Node 1 comes back online after a failover while Node 2 is successfully acting as the primary, the witness detects the stale Availability Group metadata on Node 1. It automatically takes that orphaned group `OFFLINE` and issues a `DROP AVAILABILITY GROUP` on Node 1, safely preparing it to be rebuilt later.


## 6/ build

```bash 
PS [YourFolder]\alwayson> docker compose build --no-cache
```

See the output in : [docker_build.output](CBhDS-Site/alwayson/docker_build.output)


    Note on "SQL Server needs to be restarted" messages:
    
    #11 [mssqlaagnode2 6/9] RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true
    #11 0.560 SQL Server needs to be restarted in order to apply this setting. Please run
    #11 0.560 'systemctl restart mssql-server.service'.
    #11 DONE 0.6s
    
    You can safely ignore it.
    During docker build, SQL Server isn't running, so mssql-conf prints this standard warning.
    However, the setting is written to the config file. When your container boots up via docker-compose up, SQL Server start fresh, reads the file, and automatically enables the Agent and HADR right away. No manual restart is needed.

```bash 
PS [YourFolder]\alwayson> docker compose up -d                                 
time="2026-06-14T11:28:33+02:00" level=warning msg="[YourFolder]\docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
[+] up 5/5
 ✔ Network alwayson_sqlalwayson    Created                                                                   0.1s
 ✔ Volume alwayson_alwayson_shared Created                                                                   0.0s
 ✔ Container mssqlaagnode2         Started                                                                   1.0s
 ✔ Container mssqlaagnode1         Started                                                                   0.9s
 ✔ Container aag-witness           Started                                                                   1.3s

What's next:
    Filter, search, and stream logs from all your Compose services
    in one place with Docker Desktop's Logs view. docker-desktop://dashboard/logs?appId=alwayson
PS [YourFolder]\alwayson>
```

See the output in each logs of the containers using:
```bash
PS [YourFolder]\alwayson> docker logs mssqlaagnode1 -f
PS [YourFolder]\alwayson> docker logs mssqlaagnode2 -f
PS [YourFolder]\alwayson> docker logs aag-witness -f
```

The outputs are in the files:

- [docker_logs_mssqlaagnode1.output](CBhDS-Site/alwayson/docker_logs_mssqlaagnode1.output)
- [docker_logs_mssqlaagnode2.output](CBhDS-Site/alwayson/docker_logs_mssqlaagnode1.output)
- [docker_logs_aag-witness.output](CBhDS-Site/alwayson/docker_logs_aag-witness.output)

At the end we have an healthy cluster:

![Cluster Healthy Status](/CBhDS-Site/alwayson/healthy.png)

![Secondary Node Status](/CBhDS-Site/alwayson/healthy_secondary.png)

![Primary Node Status](/CBhDS-Site/alwayson/healthy_primary.png)


    Note if you encounter any problems and need to reset everything. I recommend...
    PS [YourFolder]\alwayson> docker compose down -v    
    time="2026-06-14T11:26:53+02:00" level=warning msg="[YourFolder]\alwayson\docker-compose.yml: the attribute `version` is     obsolete, it will be ignored, please remove it to avoid potential confusion"
    [+] down 5/5
     ✔ Container aag-witness           Removed                                                                   1.5s
     ✔ Container mssqlaagnode1         Removed                                                                   1.9s
     ✔ Container mssqlaagnode2         Removed                                                                   2.1s
     ✔ Network alwayson_sqlalwayson    Removed                                                                   0.4s
     ✔ Volume alwayson_alwayson_shared Removed                                                                   0.0s
    PS [YourFolder]\alwayson> 

## 7/ Failover exercices

I did some tests. mssqlaagnode2 shutdown and restart and finally mssqlaagnode1 shutdown and restart.
Look at the witness output in the logs of the container using:

```bash 
PS [YourFolder]\alwayson> docker logs aag-witness -f
```
It looks like: [failover_exercices.output](/CBhDS-Site/alwayson/failover_exercices.output)

and the screenshots:

**SCENARIO A: SHUTDOWN mssqlaagnode2 - No failover, cluster in degadred mode**
![Secondary Node Down](/CBhDS-Site/alwayson/secondary_down.png)

**SCENARIO B: RESTART mssqlaagnode2 - Resync**
![Secondary Node Restart and Resync](/CBhDS-Site/alwayson/secondary_restart.png)

**SCENARIO C: SHUTDOWN mssqlaagnode1 - Failover and evition of mssqlaagnode1 from the group on mssqlaagnode2. mssqlaagnode2 is the new PRIMARY. Cluster in degraded mode**
![Secondary Node is the New Primary](/CBhDS-Site/alwayson/secondary_is_the_new_primary.png)

**SCENARIO D: RESTART mssqlaagnode1 - Split brain detected, group offlined and removed from mssqlaagnode1. DB needs to be re-added in the group**
![Primary Restart and Cluster Cleanup](/CBhDS-Site/alwayson/primary_restart_remove.png)

    Remember, after  mssqlaagnode1 restart, the group replicas is composed of  mssqlaagnode2 only.
    You have the option to manually ressed the database or re-initiate the conf using docker as previously.
