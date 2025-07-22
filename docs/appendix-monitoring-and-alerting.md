# Appendix – Monitoring & Alerting (KQL / PowerShell)

## Azure Monitor – KQL Samples

```kusto
// VM CPU / Memory
Perf
| where Computer in ("sqlvm1","sqlvm2")
| where CounterName in ("% Processor Time","Available MBytes")
| summarize avg(CounterValue) by Computer, CounterName, bin(TimeGenerated, 5m)
```

```kusto
// SQL Perf Counters
Perf
| where ObjectName contains "SQL"
| where CounterName in ("Batch Requests/sec","Page life expectancy")
| summarize avg(CounterValue) by Computer, CounterName, bin(TimeGenerated, 5m)
```

```kusto
// AG-related events
Event
| where Computer in ("sqlvm1","sqlvm2")
| where EventLog == "Application"
| where Source == "MSSQLSERVER"
| where EventID in (1480,35202,35206)
| project TimeGenerated, Computer, EventID, RenderedDescription
```

## PowerShell Health Check Function

```powershell
function Test-SQLHAHealth {
    param(
        [string[]]$Servers = @("sqlvm1","sqlvm2"),
        [string]$AGName = "TestAG"
    )

    foreach ($Server in $Servers) {
        Write-Host "Checking $Server..." -ForegroundColor Yellow

        if (Test-NetConnection -ComputerName $Server -Port 1433 -WarningAction SilentlyContinue) {
            Write-Host "✓ SQL connectivity OK" -ForegroundColor Green
        } else {
            Write-Host "✗ SQL connectivity FAILED" -ForegroundColor Red
        }

        $Query = @"
SELECT r.replica_server_name, r.role_desc, rs.connected_state_desc, rs.synchronization_health_desc
FROM sys.availability_replicas r
JOIN sys.dm_hadr_availability_replica_states rs ON r.replica_id = rs.replica_id
WHERE r.replica_server_name = '$Server'
"@

        try {
            $Result = Invoke-Sqlcmd -ServerInstance $Server -Query $Query
            Write-Host ("✓ AG Status: {0} - {1}" -f $Result.role_desc,$Result.synchronization_health_desc) -ForegroundColor Green
        } catch {
            Write-Host "✗ AG Status check FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
```

## Log Analytics Workspace & Agent

```bash
az monitor log-analytics workspace create   --resource-group <RG>   --workspace-name sql-logs   --location <LOC>

az vm extension set   --resource-group <RG>   --vm-name sqlvm1   --name MicrosoftMonitoringAgent   --publisher Microsoft.EnterpriseCloud.Monitoring   --settings '{"workspaceId":"<WS-ID>"}'   --protected-settings '{"workspaceKey":"<WS-KEY>"}'
```

## Alerting Ideas

- Metric alerts: CPU > 80% (5 min), PLE < threshold, disk latency.  
- Log alerts: specific AG state-change events, failed backups.  
- Route to email / Teams / PagerDuty / Webhook.
