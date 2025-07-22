<!--
keywords: azure sql server, high availability, always on availability groups, azure deployment, sql server clustering, azure load balancer, infrastructure as code, bash automation, azure key vault, managed identities, disaster recovery, sql server 2019, azure networking, devops automation
-->

# Azure SQL Server High Availability Infrastructure Deployment

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Azure](https://img.shields.io/badge/Azure-Ready-blue?logo=microsoft-azure)](https://azure.microsoft.com)
[![SQL Server 2019](https://img.shields.io/badge/SQL%20Server-2019-red?logo=microsoft-sql-server)](https://www.microsoft.com/sql-server/sql-server-2019)
[![Bash Script](https://img.shields.io/badge/Bash-Script-green?logo=gnu-bash)](https://www.gnu.org/software/bash/)

> **Azure SQL Server High Availability Deployment** - Automated infrastructure deployment for SQL Server Always On Availability Groups on Microsoft Azure. Features include Azure Load Balancer configuration, Key Vault integration, managed identities, and comprehensive post-deployment guides. Perfect for DBAs and DevOps engineers looking to quickly deploy production-ready SQL Server HA environments.

A production-ready automated deployment solution for SQL Server high availability infrastructure on Azure, designed for Always On Availability Groups configuration.

## 🎯 Overview

This solution provides a **one-click deployment** script that creates a complete SQL Server high availability infrastructure on Azure. The script automates the creation of all necessary Azure resources while following Microsoft best practices for security, networking, and high availability.

### 🚀 What Gets Deployed

- **2x SQL Server 2019 VMs** in an Availability Set
- **Azure Load Balancer** (Standard SKU) pre-configured for AG Listener
- **Virtual Network** with custom subnet and NSG rules
- **Azure Key Vault** for secure credential management
- **Managed Identities** for enhanced security
- **Premium SSD storage** optimized for SQL Server workloads

### ⏱️ Deployment Time

- **Infrastructure**: ~15-20 minutes
- **Post-configuration**: ~30-45 minutes (manual)

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Features](#-features)
- [Deployment Guide](#-deployment-guide)
- [Post-Deployment Configuration](#-post-deployment-configuration)
- [Security](#-security)
- [Cost Analysis](#-cost-analysis)
- [Troubleshooting](#-troubleshooting)
- [Best Practices](#-best-practices)
- [FAQ](#-faq)
- [Contributing](#-contributing)

## 📌 Prerequisites

### Required Tools
| Tool | Minimum Version | Installation Guide |
|------|----------------|-------------------|
| Azure CLI | 2.40.0+ | [Install Guide](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| Bash | 4.0+ | Included in Linux/macOS, [WSL for Windows](https://docs.microsoft.com/windows/wsl/install) |
| curl | Any | Usually pre-installed |

### Azure Requirements
- ✅ Active Azure Subscription
- ✅ Contributor or Owner role on subscription
- ✅ Available quota for:
  - 2x Standard_D2s_v3 VMs
  - 1x Standard Load Balancer
  - 6x Premium SSD disks

### Quick Prerequisites Check
```bash
# Check Azure CLI
az --version

# Check Azure login
az account show

# Check available VM quota
az vm list-usage --location centralus --query "[?name.value=='standardDSv3Family'].{Name:name.value, Current:currentValue, Limit:limit}" -o table

## 🚀 Quick Start

1. Download and Run

```bash
# Download the script
curl -O https://raw.githubusercontent.com/yourusername/azure-sql-ha/main/deploy-sql-vms-simple.sh

# Make it executable
chmod +x deploy-sql-vms-simple.sh

# Run the deployment
./deploy-sql-vms-simple.sh
```

2. What Happens Next

The script will:

- ✅ Generate unique resource names with timestamp
- ✅ Create all Azure resources
- ✅ Configure networking and security
- ✅ Store credentials securely in Key Vault
- ✅ Output connection information
- ✅ Save deployment details to a file

## Architecture

### Network Topology

![SQL HA Architecture](images/sql-ha-architecture-resized.png)

### High Availability Design

![SQL HA Architecture](images/ha-design.png)

## ✨ Features

### 🔐 Security Features

- Azure Key Vault Integration: All credentials stored securely
- Managed Identities: No passwords in code or config files
- Network Isolation: Custom VNet with strict NSG rules
- Temporary Public IPs: Only for initial configuration, easily removed
- Role-Based Access: VMs have minimal required permissions

### 🚀 Performance Features

- Premium SSD Storage: Optimized for SQL Server workloads
- Availability Sets: Protection against hardware failures
- Standard Load Balancer: High performance and reliability
- SQL VM Resource Provider: Automated patching and backups

### 🛠️ Operational Features

- Automated Deployment: Single script execution
- Idempotent Operations: Safe to re-run
- Comprehensive Logging: Color-coded output for easy tracking
- Deployment Records: Timestamped files with all details
- Error Recovery: Graceful handling with cleanup guidance

## 📖 Deployment Guide

Step-by-Step Walkthrough

1. Pre-Deployment Checklist

```bash
# Login to Azure
az login

# Set subscription (if multiple)
az account set --subscription "Your Subscription Name"

# Verify subscription
az account show --query "{Name:name, ID:id, State:state}" -o table
```

2. Customize Deployment (Optional)

Edit the script to modify:

```bash
# Default values you can change
LOCATION="centralus"           # Azure region
VM_SIZE="Standard_D2s_v3"      # VM size
ADMIN_USERNAME="sqladmin"      # Admin username
```

3. Run Deployment

```bash
./deploy-sql-vms-simple.sh
```

4. Monitor Progress

The script provides real-time status updates:

```bash
✓ Resource group creation completed successfully
✓ Key Vault creation completed successfully
✓ Virtual network creation completed successfully
... (continues for all resources)
```

5. Access Deployment Information

After completion, find your deployment details:

```bash
# View the generated deployment file
cat deployment-info-[TIMESTAMP].txt

# Retrieve credentials
az keyvault secret show --vault-name [YOUR-KEYVAULT] --name sql-admin-password --query value -o tsv
```

## 🔧 Post-Deployment Configuration

### Phase 1: Initial VM Access

1. Connect to VMs

```bash
# From Windows
mstsc /v:[VM-PUBLIC-IP]

# From macOS/Linux
# Use Microsoft Remote Desktop or similar
```

2. Configure Firewall Rules (Run on both VMs)

```bash
# Allow SQL Server
New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow

# Allow AG Endpoint
New-NetFirewallRule -DisplayName "AG Endpoint" -Direction Inbound -Protocol TCP -LocalPort 5022 -Action Allow

# Allow Probe Port
New-NetFirewallRule -DisplayName "SQL Probe Port" -Direction Inbound -Protocol TCP -LocalPort 59999 -Action Allow
```

### Phase 2: Windows Failover Cluster

1. Install Clustering Feature (Both VMs)

```bash
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools
Restart-Computer
```

2. Create Cluster (Run from VM1)

```bash
New-Cluster -Name SQLCLUSTER -Node sqlvm1,sqlvm2 -NoStorage

# Configure for Azure
(Get-Cluster).SameSubnetDelay = 2000
(Get-Cluster).SameSubnetThreshold = 15
```

### Phase 3: SQL Server Always On

1. Enable Always On (Both VMs)
    - Open SQL Server Configuration Manager
    - Right-click SQL Server service → Properties
    - Enable Always On Availability Groups
    - Restart SQL Server service

2. Create AG Endpoints (Both VMs)











