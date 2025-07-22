<!--
keywords: azure sql server, high availability, always on availability groups, azure deployment, sql server clustering, azure load balancer, infrastructure as code, bash automation, azure key vault, managed identities, disaster recovery, sql server 2019, azure networking, devops automation
-->

# Azure SQL Server High Availability Infrastructure Deployment 

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Azure](https://img.shields.io/badge/Azure-Ready-blue?logo=microsoft-azure)](https://azure.microsoft.com)
[![SQL Server 2019](https://img.shields.io/badge/SQL%20Server-2019-red?logo=microsoft-sql-server)](https://www.microsoft.com/sql-server/sql-server-2019)
[![Bash Script](https://img.shields.io/badge/Bash-Script-green?logo=gnu-bash)](https://www.gnu.org/software/bash/)

> **Automated deployment of a production-ready SQL Server Always On Availability Groups (AG) infrastructure on Microsoft Azure.**  
> Includes Azure Load Balancer configuration, Key Vault integration, Managed Identities, and comprehensive post-deployment guidance.

---

## Table of Contents

- [Overview](#overview)
- [What Gets Deployed](#what-gets-deployed)
- [Deployment Time](#deployment-time)
- [Prerequisites](#prerequisites)
  - [Required Tools](#required-tools)
  - [Azure Requirements](#azure-requirements)
  - [Quick Prerequisites Check](#quick-prerequisites-check)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
  - [Network Topology](#network-topology)
  - [High Availability Design](#high-availability-design)
- [Features](#features)
  - [Security Features](#security-features)
  - [Performance Features](#performance-features)
  - [Operational Features](#operational-features)
- [Deployment Guide](#deployment-guide)
- [Post-Deployment Configuration](#post-deployment-configuration)
  - [Phase 1: Initial VM Access](#phase-1-initial-vm-access)
  - [Phase 2: Windows Failover Cluster](#phase-2-windows-failover-cluster)
  - [Phase 3: SQL Server Always On](#phase-3-sql-server-always-on)
  - [Phase 4: Configure AG Listener](#phase-4-configure-ag-listener)
- [Security](#security)
  - [Security Best Practices Implemented](#security-best-practices-implemented)
  - [Post-Deployment Security Hardening](#post-deployment-security-hardening)
- [Cost Analysis](#cost-analysis)
  - [Estimated Monthly Costs](#estimated-monthly-costs)
  - [Cost Optimization Strategies](#cost-optimization-strategies)
- [Troubleshooting](#troubleshooting)
  - [Common Issues and Solutions](#common-issues-and-solutions)
- [Best Practices](#best-practices)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)
- [Appendices](#appendices)
- [Changelog](#changelog)

---

## Overview

This solution provides a **one-click deployment** script that creates a complete SQL Server high availability infrastructure on Azure, following Microsoft best practices for security, networking, and high availability.

### What Gets Deployed 

- 2× SQL Server 2019 VMs in an Availability Set  
- Azure Standard Load Balancer preconfigured for the AG Listener  
- Virtual Network with custom subnet and NSG rules  
- Azure Key Vault for secure credential management  
- Managed Identities for enhanced security  
- Premium SSD storage optimized for SQL Server workloads

###  Deployment Time 

- **Infrastructure:** ~15–20 minutes  
- **Post-configuration:** ~30–45 minutes (manual)

---

## Prerequisites 

### Required Tools 

| Tool      | Minimum Version | Installation Guide |
|-----------|------------------|--------------------|
| Azure CLI | 2.40.0+          | <https://learn.microsoft.com/cli/azure/install-azure-cli> |
| Bash      | 4.0+             | Included in Linux/macOS, or use [WSL on Windows](https://learn.microsoft.com/windows/wsl/install) |
| curl      | Any              | Usually pre-installed |

### Azure Requirements 

- Active Azure Subscription  
- Contributor or Owner role on the subscription  
- Available quota for:  
  - 2× `Standard_D2s_v3` VMs  
  - 1× Standard Load Balancer  
  - 6× Premium SSD disks

### Quick Prerequisites Check 

```bash
# Check Azure CLI
az --version

# Check Azure login
az account show

# Check available VM quota
az vm list-usage --location centralus   --query "[?name.value=='standardDSv3Family'].{Name:name.value, Current:currentValue, Limit:limit}" -o table
```

---

##  Quick Start 

1. **Download and run**

```bash
curl -O https://raw.githubusercontent.com/yourusername/azure-sql-ha/main/deploy-sql-vms-simple.sh
chmod +x deploy-sql-vms-simple.sh
./deploy-sql-vms-simple.sh
```

2. **What happens next**

The script will:

- Generate unique resource names with timestamp  
- Create all Azure resources  
- Configure networking and security  
- Store credentials securely in Key Vault  
- Output connection information  
- Save deployment details to a file

3. **Expected Output (sample)**

```text
🔄 Starting Azure SQL HA Infrastructure Deployment...
✓ Resource group creation completed successfully
✓ Key Vault creation completed successfully
✓ Virtual network creation completed successfully
...
🎉 Deployment completed in 18 minutes
📄 Deployment details saved to: deployment-info-20240722-143052.txt
```

---

## Architecture 

### Network Topology 

![SQL HA Network Topology diagram showing VNet, subnets, load balancer, and two SQL VMs](images/sql-ha-architecture-resized.png "SQL HA Architecture - Network Topology")

### High Availability Design 

![High Availability design diagram illustrating AG replicas, listener, and probe port](images/ha-design.png "High Availability Design for SQL Server AG")

---

## Features 

### Security Features 

- Azure Key Vault integration: all credentials stored securely  
- Managed Identities: no passwords in code or config files  
- Network isolation: custom VNet with strict NSG rules  
- Temporary Public IPs: only for initial configuration, easily removed  
- Role-based access: VMs have minimal required permissions

### Performance Features

- Premium SSD storage: optimized for SQL Server workloads  
- Availability Sets: protection against hardware failures  
- Standard Load Balancer: high performance and reliability  
- SQL VM Resource Provider: automated patching and backups

### Operational Features 

- Automated deployment: single script execution  
- Idempotent operations: safe to re-run  
- Comprehensive logging: color-coded output for easy tracking  
- Deployment records: timestamped files with all details  
- Error recovery: graceful handling with cleanup guidance

---

## Deployment Guide

### 1. Pre-Deployment Checklist

```bash
az login
az account set --subscription "Your Subscription Name"
az account show --query "{Name:name, ID:id, State:state}" -o table
```

### 2. Customize Deployment (Optional)

```bash
# Defaults you can change in the script
LOCATION="centralus"        # Azure region
VM_SIZE="Standard_D2s_v3"   # VM size
ADMIN_USERNAME="sqladmin"   # Admin username
```

### 3. Run Deployment

```bash
./deploy-sql-vms-simple.sh
```

### 4. Monitor Progress

See real-time status lines like:

```text
✓ Resource group creation completed successfully
✓ Key Vault creation completed successfully
✓ Virtual network creation completed successfully
... (continues for all resources)
```

### 5. Access Deployment Information

```bash
cat deployment-info-[TIMESTAMP].txt
az keyvault secret show --vault-name <YOUR-KEYVAULT> --name sql-admin-password --query value -o tsv
```

---

## Post-Deployment Configuration

### Phase 1: Initial VM Access 

```bash
# Windows
mstsc /v:<VM-PUBLIC-IP>
# macOS/Linux -> use Microsoft Remote Desktop or any RDP client
```

**Firewall rules (run on both VMs):**

```powershell
New-NetFirewallRule -DisplayName "SQL Server"     -Direction Inbound -Protocol TCP -LocalPort 1433  -Action Allow
New-NetFirewallRule -DisplayName "AG Endpoint"    -Direction Inbound -Protocol TCP -LocalPort 5022  -Action Allow
New-NetFirewallRule -DisplayName "SQL Probe Port" -Direction Inbound -Protocol TCP -LocalPort 59999 -Action Allow
```

### Phase 2: Windows Failover Cluster

```powershell
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools
Restart-Computer
```

```powershell
New-Cluster -Name SQLCLUSTER -Node sqlvm1,sqlvm2 -NoStorage
(Get-Cluster).SameSubnetDelay     = 2000
(Get-Cluster).SameSubnetThreshold = 15
```

### Phase 3: SQL Server Always On 

Enable Always On via SQL Server Configuration Manager (GUI) or PowerShell, then:

```sql
CREATE ENDPOINT [Hadr_endpoint]
STATE = STARTED
AS TCP (LISTENER_PORT = 5022)
FOR DATA_MIRRORING (
    ROLE = ALL,
    ENCRYPTION = REQUIRED ALGORITHM AES
);
```

Create database, backup, and AG:

```sql
CREATE DATABASE TestDB;
BACKUP DATABASE TestDB TO DISK = 'C:\Backup\TestDB.bak';

CREATE AVAILABILITY GROUP [TestAG]
FOR DATABASE [TestDB]
REPLICA ON 
    'sqlvm1' WITH (ENDPOINT_URL = 'TCP://sqlvm1:5022', AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, FAILOVER_MODE = AUTOMATIC),
    'sqlvm2' WITH (ENDPOINT_URL = 'TCP://sqlvm2:5022', AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, FAILOVER_MODE = AUTOMATIC);
```

(See **Advanced Troubleshooting** appendix for full secondary join/restore steps.)

### Phase 4: Configure AG Listener 

```sql
ALTER AVAILABILITY GROUP [TestAG]
ADD LISTENER 'AGListener' (
    WITH IP (('10.0.1.100', '255.255.255.0')),
    PORT = 1433
);
```

```powershell
$ClusterNetworkName = "Cluster Network 1"
$IPResourceName     = "AGListener_10.0.1.100"
$ListenerILBIP      = "10.0.1.100"
[int]$ProbePort     = 59999

Import-Module FailoverClusters
Get-ClusterResource $IPResourceName | Set-ClusterParameter -Multiple @{
    Address    = $ListenerILBIP;
    ProbePort  = $ProbePort;
    SubnetMask = "255.255.255.255";
    Network    = $ClusterNetworkName;
    EnableDhcp = 0
}
```

---

## Security 

### Security Best Practices Implemented 

| Feature               | Implementation            | Benefit                          |
|-----------------------|---------------------------|----------------------------------|
| Credential Management | Azure Key Vault           | No hardcoded passwords           |
| Network Security      | Custom NSG rules          | Minimal attack surface           |
| Identity Management   | Managed Identities        | No credential rotation needed    |
| Access Control        | RBAC + Key Vault policies | Principle of least privilege     |
| Encryption            | TLS for AG endpoints      | Data in transit protection       |

### Post-Deployment Security Hardening 

```bash
# Remove Public IPs when done
az network public-ip delete -g <RG> -n sqlvm1-pip --yes
az network public-ip delete -g <RG> -n sqlvm2-pip --yes
```

```bash
# Enable Azure Bastion (recommended)
az network bastion create   --name sql-bastion   --public-ip-address sql-bastion-pip   --resource-group <RG>   --vnet-name sql-vnet
```

Further hardening guidance is in **Appendix – Security Hardening (Advanced)**.

---

## Cost Analysis 

### Estimated Monthly Costs (Central US) {#estimated-monthly-costs}

| Resource       | Spec                                    | Est. Monthly Cost |
|----------------|------------------------------------------|-------------------:|
| 2× SQL VMs     | Standard_D2s_v3 (2 vCPU, 8 GB RAM)       | $280               |
| Storage        | 2× OS (128 GB) + 4× Data (128/256 GB)    | $140               |
| Load Balancer  | Standard SKU                             | $25                |
| Key Vault      | Standard tier                            | <$1                |
| Network        | 100 GB egress                            | $9                 |
| **Total**      |                                          | **~$455/month**    |

### Cost Optimization Strategies 

- B-series VMs for dev/test (save ~40%)  
- Auto-shutdown schedules (save ~50%)  
- Dev/Test subscription (save ~55%)  
- Reserved Instances (1y: ~40%, 3y: ~60%)  
- Azure Hybrid Benefit (save ~40%)  
- Tier storage appropriately

Deep-dive numbers & scripts in **Appendix – Cost, ROI & TCO Analysis**.

---

## Troubleshooting

### Common Issues and Solutions 

**Cluster Creation Fails**

```powershell
Test-Cluster -Node sqlvm1,sqlvm2
Test-NetConnection -ComputerName sqlvm2 -Port 3343
```

**AG Listener Not Responding**

```powershell
Get-ClusterResource | Where-Object ResourceType -eq "IP Address"
netstat -an | findstr 59999
```

**SQL Connection Timeouts**

```sql
SELECT * FROM sys.availability_groups_cluster;
SELECT * FROM sys.dm_hadr_availability_replica_states;
```

See **Appendix – Advanced Troubleshooting** for full diagnostics and fixes.

---

## Best Practices

**Pre-Deployment**: verify quotas, plan IP scheme, document security, prep runbooks.  
**During Deployment**: monitor activity log, save outputs, test each phase.  
**Post-Deployment**: monitoring/alerts, backups, patch windows, DR plan.

---

## FAQ

- **Change region?** Yes—before deployment. Modify `LOCATION`.  
- **Different VM sizes?** Yes—ensure Premium storage support.  
- **Add more replicas?** Extend VM loop, join to cluster/AG, update LB.  
- **Why load balancer?** Azure lacks GARP; LB provides virtual IP.  
- **Probe port?** 59999 lets LB detect the primary replica.  

---

## Contributing 

See [CONTRIBUTING.md](./CONTRIBUTING.md). PR steps:

1. Fork → branch → commit → push → PR.  
2. Follow Bash best practices (`set -euo pipefail`, comments).  
3. Test changes thoroughly.

⭐ Star the repo if this helps!

---

## 📄 License

MIT License – see [LICENSE](./LICENSE).

---

## Appendices 

- 🔐 **Security Hardening (Advanced):** [docs/appendix-security-hardening.md](docs/appendix-security-hardening.md)  
- 💸 **Cost, ROI & TCO Analysis:** [docs/appendix-cost-and-roi.md](docs/appendix-cost-and-roi.md)  
- 📈 **Monitoring & Alerting (KQL/PowerShell):** [docs/appendix-monitoring-and-alerting.md](docs/appendix-monitoring-and-alerting.md)  
- 🛠️ **Advanced Troubleshooting:** [docs/appendix-troubleshooting-advanced.md](docs/appendix-troubleshooting-advanced.md)  
- 🆘 **DR Playbooks & Ops Runbooks:** [docs/appendix-dr-and-ops-runbooks.md](docs/appendix-dr-and-ops-runbooks.md)

---

<p align="right"><a href="#top">⬆️ Back to top</a></p>
