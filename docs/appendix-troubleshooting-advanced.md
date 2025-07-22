# Appendix – Advanced Troubleshooting

## Cluster Creation Fails

**Diagnostics**

```powershell
Test-Cluster -Node sqlvm1,sqlvm2 -Include "Inventory","Network","System Configuration"
Test-NetConnection -ComputerName sqlvm2 -Port 3343
Resolve-DnsName sqlvm2
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*Cluster*"}
```

**Fixes**

```powershell
Enable-NetFirewallRule -DisplayGroup "Failover Clusters"
Remove-Cluster -Force -CleanupAD   # reset if required
```

## AG Listener Not Responding

**Diagnostics**

```powershell
Get-ClusterResource | Where-Object ResourceType -eq "IP Address"
netstat -an | findstr 59999
Test-NetConnection -ComputerName 10.0.1.100 -Port 59999
```

```sql
SELECT * FROM sys.availability_group_listeners;
```

**Fix**

```powershell
$IPResourceName = "AGListener_10.0.1.100"
Get-ClusterResource $IPResourceName | Set-ClusterParameter -Name ProbePort -Value 59999
Stop-ClusterResource $IPResourceName
Start-ClusterResource $IPResourceName
```

## SQL Timeouts / Performance

**SQL Checks**

```sql
SELECT * FROM sys.availability_groups_cluster;
SELECT * FROM sys.dm_hadr_availability_replica_states;
SELECT * FROM sys.availability_group_listeners;

-- Blocking
SELECT blocking_session_id, session_id, wait_type, wait_time
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;
```

**Memory / IO**

```sql
-- Memory
SELECT counter_name, cntr_value
FROM sys.dm_os_performance_counters
WHERE counter_name IN ('Total Server Memory (KB)','Target Server Memory (KB)');

-- IO
SELECT DB_NAME(database_id) db, file_id, io_stall_read_ms, io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(NULL, NULL);
```

## Deployment Script Errors

| Error                                  | Cause                         | Fix                         |
|----------------------------------------|-------------------------------|-----------------------------|
| `QuotaExceeded`                        | Insufficient VM quota         | Request quota increase      |
| `LocationNotAvailableForResourceType`  | Service not in region         | Change LOCATION             |
| `InvalidTemplateDeployment`            | Name conflict / bad params    | Use unique names / fix vars |
| `AuthorizationFailed`                  | Insufficient RBAC permissions | Assign Owner/Contributor    |

**Diagnostics**

```bash
az deployment group show   --resource-group <RG>   --name <DEPLOYMENT-NAME>   --query "properties.error"
```

**Cleanup**

```bash
az group delete --name <RG> --yes --no-wait
```

## Emergency Commands

```sql
ALTER AVAILABILITY GROUP [TestAG] FAILOVER;
```

```powershell
Stop-ClusterResource "AGListener"
Start-ClusterResource "AGListener"
```
