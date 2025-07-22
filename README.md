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
