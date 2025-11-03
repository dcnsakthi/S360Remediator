<#
.SYNOPSIS
    Fixes Azure PowerShell module loading issues and connects to Azure

.DESCRIPTION
    This script resolves common Az module loading conflicts by:
    1. Cleaning up loaded modules
    2. Reloading Az modules properly
    3. Connecting to Azure

.EXAMPLE
    .\Fix-AzureModules.ps1
#>

[CmdletBinding()]
param()

Write-Host "`n=== Azure Module Cleanup and Connection Tool ===" -ForegroundColor Cyan

# Step 1: Remove all loaded Az modules
Write-Host "`nStep 1: Cleaning up loaded modules..." -ForegroundColor Yellow
$azModules = Get-Module -Name Az.* -ListAvailable | Select-Object -First 1
if ($azModules) {
    Get-Module Az.* | Remove-Module -Force -ErrorAction SilentlyContinue
    Write-Host "  Removed loaded Az modules" -ForegroundColor Green
}

# Step 2: Clear any assembly loading issues
Write-Host "`nStep 2: Clearing assembly cache..." -ForegroundColor Yellow
[System.AppDomain]::CurrentDomain.GetAssemblies() | 
    Where-Object { $_.FullName -like "*Azure*" } | 
    ForEach-Object {
        Write-Verbose "Loaded: $($_.FullName)"
    }

# Step 3: Import Az.Accounts first (core module)
Write-Host "`nStep 3: Importing Az.Accounts module..." -ForegroundColor Yellow
try {
    Import-Module Az.Accounts -Force -ErrorAction Stop
    Write-Host "  Az.Accounts imported successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to import Az.Accounts: $_"
    Write-Host "`nTrying alternative approach..." -ForegroundColor Yellow
    
    # Alternative: Start fresh PowerShell session
    Write-Host @"
    
Please try one of these solutions:

1. Close VS Code and PowerShell completely, then reopen
2. Or run this command in a NEW PowerShell window:
   
   pwsh -NoProfile -Command "Import-Module Az.Accounts; Connect-AzAccount"

3. Or uninstall and reinstall Az modules:
   
   Uninstall-Module -Name Az -AllVersions -Force
   Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

"@ -ForegroundColor Yellow
    exit 1
}

# Step 4: Import other required Az modules
Write-Host "`nStep 4: Importing Az.Resources module..." -ForegroundColor Yellow
try {
    Import-Module Az.Resources -Force -ErrorAction Stop
    Write-Host "  Az.Resources imported successfully" -ForegroundColor Green
} catch {
    Write-Warning "Az.Resources could not be imported: $_"
}

# Step 5: Check current Azure connection
Write-Host "`nStep 5: Checking Azure connection..." -ForegroundColor Yellow
$context = Get-AzContext -ErrorAction SilentlyContinue

if ($context) {
    Write-Host "  Already connected to Azure!" -ForegroundColor Green
    Write-Host "  Account: $($context.Account.Id)" -ForegroundColor Cyan
    Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Cyan
    Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
} else {
    Write-Host "  Not connected. Initiating connection..." -ForegroundColor Yellow
    try {
        Connect-AzAccount -ErrorAction Stop
        $context = Get-AzContext
        Write-Host "`n  Successfully connected!" -ForegroundColor Green
        Write-Host "  Account: $($context.Account.Id)" -ForegroundColor Cyan
        Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Cyan
        Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
    } catch {
        Write-Error "Failed to connect to Azure: $_"
        exit 1
    }
}

Write-Host "`n=== Ready to scan for orphaned accounts! ===" -ForegroundColor Green
Write-Host "Run: .\Remove-OrphanedAccounts.ps1 -WhatIf" -ForegroundColor Cyan
