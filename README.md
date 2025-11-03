# S360Remediator
# Azure Orphaned Accounts Remediation Tool

This tool helps identify and remove orphaned accounts (users, groups, and service principals) that no longer exist in Azure Active Directory but still have role assignments in your Azure subscriptions.

## What are Orphaned Accounts?

Orphaned accounts are identities that:
- Have been deleted from Azure Active Directory
- Still have active role assignments in Azure subscriptions
- Cannot be accessed or managed through normal means
- Represent potential security risks and compliance issues

## Prerequisites

1. **Azure PowerShell Module**: Install the Az module if not already installed
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   ```

2. **Permissions**: You need appropriate permissions to:
   - Read role assignments (e.g., Reader role)
   - Delete role assignments (e.g., User Access Administrator or Owner role)

3. **Authentication**: You must be signed in to Azure
   ```powershell
   Connect-AzAccount
   ```

## Usage

### 1. Scan for Orphaned Accounts (Preview Mode)

To see what orphaned accounts exist without making any changes:

```powershell
.\scripts\Remove-OrphanedAccounts.ps1 -WhatIf
```

### 2. Scan a Specific Subscription

To scan only one subscription:

```powershell
.\scripts\Remove-OrphanedAccounts.ps1 -SubscriptionId "your-subscription-id" -WhatIf
```

### 3. Remove Orphaned Accounts (Dry Run)

To see what would be removed:

```powershell
.\scripts\Remove-OrphanedAccounts.ps1 -RemoveOrphaned -WhatIf
```

### 4. Remove Orphaned Accounts (Actual Removal)

To actually remove orphaned accounts (you will be prompted for confirmation):

```powershell
.\scripts\Remove-OrphanedAccounts.ps1 -RemoveOrphaned
```

### 5. Remove from Specific Subscription

To remove orphaned accounts from a specific subscription:

```powershell
.\scripts\Remove-OrphanedAccounts.ps1 -SubscriptionId "your-subscription-id" -RemoveOrphaned
```

## Output

The script will:
1. Display progress as it scans each subscription
2. Show detailed information about each orphaned account found
3. Export results to a CSV file with timestamp: `OrphanedAccounts_YYYYMMDD_HHMMSS.csv`
4. Provide a summary of total assignments scanned and orphaned accounts found
5. If `-RemoveOrphaned` is used, report on removal operations

## Example Output

```
=== Azure Orphaned Accounts Remediation Tool ===
Connected as: user@domain.com
Tenant: 72f988bf-86f1-41af-91ab-2d7cd011db47

Scanning 3 subscription(s) for orphaned accounts...

Processing subscription: Production (12345678-1234-1234-1234-123456789abc)
  Found 45 role assignment(s)
  [ORPHANED] Found orphaned assignment:
    - Object ID: abcd1234-5678-90ef-ghij-klmnopqrstuv
    - Display Name: DeletedUser@domain.com
    - Role: Contributor
    - Scope: /subscriptions/12345678-1234-1234-1234-123456789abc

=== Summary ===
Total role assignments scanned: 125
Orphaned assignments found: 3

Orphaned assignments exported to: OrphanedAccounts_20251103_143022.csv
```

## Security Considerations

- **Review before removal**: Always run with `-WhatIf` first to preview changes
- **Backup**: The script exports findings to CSV before any removal
- **Confirmation**: When using `-RemoveOrphaned` without `-WhatIf`, you'll be prompted for confirmation
- **Audit trail**: Keep the exported CSV files for audit purposes
- **Permissions**: Ensure you have proper authorization to modify role assignments

## Troubleshooting

### Error: "Azure PowerShell module is not installed"
Install the Azure PowerShell module:
```powershell
Install-Module -Name Az -AllowClobber -Scope CurrentUser
```

### Error: "Not connected to Azure"
Sign in to Azure:
```powershell
Connect-AzAccount
```

### Error: "Subscription not found or not accessible"
Verify you have access to the subscription:
```powershell
Get-AzSubscription
```

### Error: Insufficient permissions
You need:
- **Reader** role (minimum) to scan role assignments
- **User Access Administrator** or **Owner** role to remove role assignments

## Best Practices

1. **Regular Scanning**: Run this script regularly (monthly recommended) to maintain clean subscriptions
2. **Documentation**: Keep CSV exports for compliance and audit purposes
3. **Staged Approach**: 
   - First, run with `-WhatIf` to identify orphaned accounts
   - Review the CSV export
   - Then run with `-RemoveOrphaned` after approval
4. **Subscription-by-Subscription**: For production environments, consider processing one subscription at a time
5. **Communication**: Notify stakeholders before removing access, even if orphaned

## Additional Resources

- [Azure RBAC Documentation](https://docs.microsoft.com/azure/role-based-access-control/)
- [Azure AD Identity Governance](https://docs.microsoft.com/azure/active-directory/governance/)
- [Azure Policy for RBAC](https://docs.microsoft.com/azure/governance/policy/)

## Support

For issues or questions:
1. Review the troubleshooting section above
2. Check Azure PowerShell module documentation
3. Verify your Azure permissions
4. Contact your Azure administrator

## Version History

- **v1.0** (2025-11-03): Initial release
  - Scan subscriptions for orphaned accounts
  - Export findings to CSV
  - Remove orphaned role assignments
  - WhatIf support for safe testing
