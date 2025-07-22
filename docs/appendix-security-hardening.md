# Appendix – Security Hardening (Advanced)

## Defense-in-Depth Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│ 🌐 Network Security    │ NSG Rules, VNet Isolation         │
│ 🔐 Identity & Access   │ Managed Identities, RBAC          │
│ 💾 Data Protection     │ TDE, Backup Encryption            │
│ 🔑 Key Management      │ Azure Key Vault                   │
│ 📊 Monitoring          │ Azure Monitor, Defender for Cloud │
│ 🛡️ Endpoint Protection │ Windows Defender, Updates         │
└─────────────────────────────────────────────────────────────┘
```

## Network Security

### Default NSG Rules (from deployment)

| Priority | Name             | Dir | Access | Proto | Source            | Dest | Port |
|---------:|------------------|-----|--------|-------|-------------------|------|-----:|
| 1000     | AllowRDP         | In  | Allow  | TCP   | Internet          |  *   | 3389 |
| 1010     | AllowSQL         | In  | Allow  | TCP   | VirtualNetwork    |  *   | 1433 |
| 1020     | AllowAGEndpoint  | In  | Allow  | TCP   | VirtualNetwork    |  *   | 5022 |
| 1030     | AllowProbe       | In  | Allow  | TCP   | AzureLoadBalancer |  *   | 59999|
| 1040     | AllowCluster     | In  | Allow  | TCP   | VirtualNetwork    |  *   | 3343 |
| 65000    | DenyAllInbound   | In  | Deny   | *     | *                 |  *   |   *  |

#### Harden After Setup

```bash
# Remove RDP from Internet once Bastion is deployed
az network nsg rule delete   --resource-group <RG>   --nsg-name sql-nsg   --name AllowRDP

# Restrict management access
az network nsg rule create   --resource-group <RG>   --nsg-name sql-nsg   --name AllowMgmtFromOffice   --priority 1000   --source-address-prefixes <YOUR-OFFICE-IP>   --destination-port-ranges 3389   --access Allow --protocol Tcp
```

## Key Vault Hardening

```bash
# Grant VM managed identity minimal access
az keyvault set-policy   --name <KV-NAME>   --object-id <VM-MSI-OBJECT-ID>   --secret-permissions get list

# Enable Key Vault audit logs
az monitor diagnostic-settings create   --resource <KV-RESOURCE-ID>   --name KeyVaultAudit   --logs '[{"category":"AuditEvent","enabled":true}]'   --workspace <LOG-ANALYTICS-ID>
```

## Windows & SQL Server Hardening

```powershell
# Defender & Windows Update
Set-MpPreference -DisableRealtimeMonitoring $false
Install-Module PSWindowsUpdate -Force
Get-WUInstall -AcceptAll -AutoReboot

# Disable unnecessary services
'Fax','RemoteRegistry','Telnet' | ForEach-Object {
  Set-Service -Name $_ -StartupType Disabled -ErrorAction SilentlyContinue
}
```

```sql
-- Disable SA if unused
ALTER LOGIN [sa] DISABLE;
GO

-- Enable SQL Server Audit
CREATE SERVER AUDIT [SQLServerAudit]
TO APPLICATION_LOG
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
ALTER SERVER AUDIT [SQLServerAudit] WITH (STATE = ON);
```

## Security Checklists

### Pre-Production

- [ ] Public IPs removed  
- [ ] Azure Bastion deployed  
- [ ] NSG rules hardened  
- [ ] SQL audit enabled  
- [ ] Defender/updates configured  
- [ ] Backup encryption enabled  
- [ ] Defender for Cloud enabled (Standard tier)  
- [ ] DR runbooks documented

### Ongoing

- [ ] Monthly patching & review  
- [ ] Quarterly access reviews  
- [ ] Annual penetration test  
- [ ] Regular backup/restore tests  
- [ ] Key rotation procedures  
- [ ] Incident response plan reviewed
