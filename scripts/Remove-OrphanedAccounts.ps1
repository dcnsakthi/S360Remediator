<#
.SYNOPSIS
    Remove orphaned accounts from Azure subscription(s)

.DESCRIPTION
    This script identifies and removes orphaned role assignments where the principal (user, group, or service principal)
    no longer exists in Azure AD but still has role assignments in Azure subscriptions.

.PARAMETER SubscriptionId
    Specific subscription ID to scan. If not provided, all accessible subscriptions will be scanned.

.PARAMETER WhatIf
    Shows what would be removed without actually removing anything.

.PARAMETER RemoveOrphaned
    Actually removes the orphaned role assignments. Use with caution!

.EXAMPLE
    .\Remove-OrphanedAccounts.ps1 -WhatIf
    Shows all orphaned accounts without removing them.

.EXAMPLE
    .\Remove-OrphanedAccounts.ps1 -SubscriptionId "your-subscription-id" -RemoveOrphaned
    Removes orphaned accounts from a specific subscription.

.EXAMPLE
    .\Remove-OrphanedAccounts.ps1 -RemoveOrphaned
    Removes orphaned accounts from all accessible subscriptions.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$RemoveOrphaned
)

# Check if Azure PowerShell module is installed
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Error "Azure PowerShell module (Az.Accounts) is not installed. Install it with: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
    exit 1
}

# Import required modules
Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Resources -ErrorAction Stop

# Connect to Azure if not already connected
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not connected to Azure. Please sign in..." -ForegroundColor Yellow
    Connect-AzAccount
    $context = Get-AzContext
}

Write-Host "`n=== Azure Orphaned Accounts Remediation Tool ===" -ForegroundColor Cyan
Write-Host "Connected as: $($context.Account.Id)" -ForegroundColor Green
Write-Host "Tenant: $($context.Tenant.Id)`n" -ForegroundColor Green

# Get subscriptions to scan
$subscriptions = @()
if ($SubscriptionId) {
    $subscriptions = @(Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue)
    if (-not $subscriptions) {
        Write-Error "Subscription $SubscriptionId not found or not accessible."
        exit 1
    }
} else {
    $subscriptions = Get-AzSubscription
}

Write-Host "Scanning $($subscriptions.Count) subscription(s) for orphaned accounts...`n" -ForegroundColor Cyan

# Track orphaned assignments
$orphanedAssignments = @()
$totalAssignments = 0

foreach ($subscription in $subscriptions) {
    Write-Host "Processing subscription: $($subscription.Name) ($($subscription.Id))" -ForegroundColor Yellow
    
    # Set subscription context
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    # Get all role assignments in the subscription
    try {
        $roleAssignments = Get-AzRoleAssignment -ErrorAction Stop
        $totalAssignments += $roleAssignments.Count
        
        Write-Host "  Found $($roleAssignments.Count) role assignment(s)" -ForegroundColor Gray
        
        foreach ($assignment in $roleAssignments) {
            # Check if the principal still exists
            $principalExists = $true
            
            # Try to get the object from Azure AD
            try {
                $objectType = $assignment.ObjectType
                
                # Check based on object type
                if ($objectType -eq "Unknown" -or [string]::IsNullOrEmpty($assignment.DisplayName) -or $assignment.DisplayName -eq "Identity not found") {
                    $principalExists = $false
                } else {
                    # Additional validation - try to get the object from Azure AD
                    $adObject = $null
                    try {
                        $adObject = Get-AzADUser -ObjectId $assignment.ObjectId -ErrorAction SilentlyContinue
                        if (-not $adObject) {
                            $adObject = Get-AzADServicePrincipal -ObjectId $assignment.ObjectId -ErrorAction SilentlyContinue
                        }
                        if (-not $adObject) {
                            $adObject = Get-AzADGroup -ObjectId $assignment.ObjectId -ErrorAction SilentlyContinue
                        }
                        
                        if (-not $adObject) {
                            $principalExists = $false
                        }
                    } catch {
                        $principalExists = $false
                    }
                }
                
                if (-not $principalExists) {
                    Write-Host "  [ORPHANED] Found orphaned assignment:" -ForegroundColor Red
                    Write-Host "    - Object ID: $($assignment.ObjectId)" -ForegroundColor Red
                    Write-Host "    - Display Name: $($assignment.DisplayName)" -ForegroundColor Red
                    Write-Host "    - Role: $($assignment.RoleDefinitionName)" -ForegroundColor Red
                    Write-Host "    - Scope: $($assignment.Scope)" -ForegroundColor Red
                    
                    $orphanedAssignments += [PSCustomObject]@{
                        SubscriptionName = $subscription.Name
                        SubscriptionId = $subscription.Id
                        RoleAssignmentId = $assignment.RoleAssignmentId
                        ObjectId = $assignment.ObjectId
                        DisplayName = $assignment.DisplayName
                        RoleDefinitionName = $assignment.RoleDefinitionName
                        Scope = $assignment.Scope
                        ObjectType = $assignment.ObjectType
                    }
                }
            } catch {
                Write-Verbose "Error checking assignment: $_"
            }
        }
    } catch {
        Write-Warning "Error processing subscription $($subscription.Name): $_"
    }
    
    Write-Host ""
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total role assignments scanned: $totalAssignments" -ForegroundColor White
Write-Host "Orphaned assignments found: $($orphanedAssignments.Count)" -ForegroundColor $(if ($orphanedAssignments.Count -gt 0) { "Red" } else { "Green" })

if ($orphanedAssignments.Count -eq 0) {
    Write-Host "`nNo orphaned accounts found! Your subscriptions are clean." -ForegroundColor Green
    exit 0
}

# Export results to CSV
$exportPath = Join-Path $PSScriptRoot "OrphanedAccounts_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$orphanedAssignments | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host "`nOrphaned assignments exported to: $exportPath" -ForegroundColor Green

# Display orphaned assignments in a table
Write-Host "`n=== Orphaned Assignments Details ===" -ForegroundColor Cyan
$orphanedAssignments | Format-Table -Property SubscriptionName, DisplayName, RoleDefinitionName, ObjectType, Scope -AutoSize

# Remove orphaned assignments if requested
if ($RemoveOrphaned) {
    Write-Host "`n=== Removing Orphaned Assignments ===" -ForegroundColor Yellow
    Write-Warning "You are about to remove $($orphanedAssignments.Count) orphaned role assignment(s)."
    
    if (-not $WhatIf) {
        $confirmation = Read-Host "Are you sure you want to proceed? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    $removedCount = 0
    foreach ($assignment in $orphanedAssignments) {
        try {
            Set-AzContext -SubscriptionId $assignment.SubscriptionId | Out-Null
            
            if ($WhatIf) {
                Write-Host "[WHATIF] Would remove: $($assignment.DisplayName) - $($assignment.RoleDefinitionName) on $($assignment.Scope)" -ForegroundColor Yellow
            } else {
                Remove-AzRoleAssignment -ObjectId $assignment.ObjectId -RoleDefinitionName $assignment.RoleDefinitionName -Scope $assignment.Scope -ErrorAction Stop
                Write-Host "[REMOVED] $($assignment.DisplayName) - $($assignment.RoleDefinitionName) on $($assignment.Scope)" -ForegroundColor Green
                $removedCount++
            }
        } catch {
            Write-Warning "Failed to remove assignment for $($assignment.DisplayName): $_"
        }
    }
    
    if (-not $WhatIf) {
        Write-Host "`nSuccessfully removed $removedCount out of $($orphanedAssignments.Count) orphaned assignment(s)." -ForegroundColor Green
    }
} elseif ($WhatIf) {
    Write-Host "`n[WHATIF MODE] To actually remove these orphaned accounts, run the script with -RemoveOrphaned parameter." -ForegroundColor Yellow
} else {
    Write-Host "`nTo remove these orphaned accounts, run the script again with -RemoveOrphaned parameter." -ForegroundColor Yellow
    Write-Host "To preview changes without removing, use -WhatIf parameter." -ForegroundColor Yellow
}

Write-Host "`nScript completed." -ForegroundColor Cyan
