# Appendix – DR Playbooks & Ops Runbooks

## Disaster Recovery Checklist

1. **Assess**
   - Identify failed component (VM, SQL instance, cluster role)
   - Automatic vs. manual failover? Data loss risk?

2. **Stabilize**
   - Ensure production workload is online (primary/secondary)
   - Communicate status to stakeholders

3. **Recover**
   - Restore failed node / service
   - Rejoin to cluster / AG
   - Validate synchronization

4. **Verify**
   - Confirm monitoring/alerts green
   - Update incident ticket

5. **Post-Mortem**
   - Root cause analysis
   - Action items & documentation updates

## Contact Template

```
Primary DBA:      Name / Phone / Email
Secondary DBA:    Name / Phone / Email
Azure Support:    <Plan ID / Portal link>
Network Team:     <Contact>
Application Team: <Contact>

Subscription ID:  <...>
Resource Group:   <...>
Key Vault:        <...>
AG Listener:      AGListener (10.0.1.100)
```

## Runbooks

### Planned Failover

1. Ensure secondary is SYNCHRONOUS & HEALTHY.  
2. Execute:
   ```sql
   ALTER AVAILABILITY GROUP [TestAG] FAILOVER;
   ```
3. Validate app connections.  
4. Patch former primary.  
5. Fail back if desired.

### Forced Failover (Last Resort)

```sql
ALTER AVAILABILITY GROUP [TestAG] FORCE_FAILOVER_ALLOW_DATA_LOSS;
```
> Use only if primary is unrecoverable and business impact is critical.

### Backup & Restore Validation

1. Restore latest full + log backups to dev/test.  
2. Run `DBCC CHECKDB`.  
3. Record RTO/RPO metrics.

## Operational Schedules

- **Daily**: Check AG dashboard, cluster health, alerts.  
- **Weekly**: Verify backups, storage growth, security alerts.  
- **Monthly**: Patch OS/SQL (secondary first), review spend.  
- **Quarterly**: Access review, DR drill.  
- **Yearly**: Pen test, architecture review.

## Change Management Flow

1. Dev test → staging → production.  
2. Maintenance windows with rollback plan.  
3. Document all changes (config, scripts).
