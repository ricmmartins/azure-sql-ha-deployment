# Appendix – Cost, ROI & TCO Analysis

## Monthly Cost Breakdown (Central US)

| Category   | Component           | Spec / Qty                    | Cost    |
|------------|---------------------|-------------------------------|--------:|
| Compute    | 2× Standard_D2s_v3  | 2 vCPU, 8 GB RAM              | $280.32 |
| Storage    | OS Disks (P6 128 GB)| 2                             | $39.42  |
| Storage    | Data Disks (P10 256 GB)| 2                          | $76.80  |
| Storage    | Log Disks (P6 128 GB)| 2                            | $39.42  |
| Networking | Load Balancer Std   | 1                             | $25.00  |
| Networking | 100 GB Egress       | ~                             | $8.70   |
| Security   | Key Vault Std       | 1                             | <$1     |
| Monitoring | Log Analytics (1 GB)| 1                             | $2.30   |
| **Total**  |                     |                               | **~$472** |

## VM Size Comparison

| Size              | vCPU | RAM  | 2-VM Cost | Use Case            |
|-------------------|------|------|----------:|---------------------|
| Standard_B2s      | 2    | 4 GB | $62.56    | Dev/Test            |
| Standard_D2s_v3   | 2    | 8 GB | $280.32   | Small Prod          |
| Standard_D4s_v3   | 4    |16 GB | $560.64   | Medium Prod         |
| Standard_D8s_v3   | 8    |32 GB | $1,121.28 | Large Prod          |
| Standard_E4s_v3   | 4    |32 GB | $613.44   | Memory Intensive    |

## Savings Levers

### Auto-Shutdown (Dev/Test)

```bash
az vm auto-shutdown   --resource-group <RG>   --name sqlvm1   --time 1800   --email you@contoso.com
```

### Reserved Instances

| Term | PAYG | Reserved | Savings |
|------|------|----------|---------|
| 1 yr | 100% | ~60%     | ~40%    |
| 3 yr | 100% | ~40%     | ~60%    |

### Azure Hybrid Benefit

```bash
az vm update --resource-group <RG> --name sqlvm1 --license-type AHUB
```

### Storage Tiering

```bash
az disk update   --resource-group <RG>   --name sqlvm1-datadisk-1   --sku Standard_LRS
```

## Budgets & Alerts

```bash
az consumption budget create   --resource-group <RG>   --budget-name sql-ha-budget   --amount 600   --time-grain Monthly   --start-date 2025-07-01   --end-date 2026-07-01
```

## ROI Snapshot

- **HA extra monthly cost:** ~$332  
- **Downtime cost threshold:** if downtime > $1k/hour, ~20 minutes saved/month justifies HA.

## 3-Year TCO (Example)

| Component  | Yr1  | Yr2  | Yr3  | Total  |
|------------|-----:|-----:|-----:|-------:|
| Infra      | 5,664| 5,664| 5,664| 17,000 |
| Ops Mgmt   | 2,400| 2,400| 2,400| 7,200  |
| Licensing  | 3,600| 3,600| 3,600| 10,800 |
| Training   | 1,500| 500  | 500  | 2,500  |
| **TCO**    |13,164|12,164|12,164| 37,492 |

### Optimization Roadmap

- **Months 1–3:** Baseline usage, monitor.  
- **4–6:** Auto-shutdown, Hybrid Benefit, storage right-sizing.  
- **7–12:** Buy 1-year RIs, mature monitoring.  
- **Year 2+:** 3-year RIs, newer VM SKUs, more automation.
