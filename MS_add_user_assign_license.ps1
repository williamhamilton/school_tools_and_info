.SYNOPSIS
Creates Azure AD users from a CSV and assigns a Microsoft 365 license.

.DESCRIPTION
- Batch-create users using Microsoft Graph PowerShell.
- Assigns license by SkuId or SkuPartNumber.
- Optionally suppress Exchange mailbox creation.
- Supports DryRun mode to preview actions.

.EXAMPLE
# Dry-run with CSV
.\MS_add_user_assign_license.ps1 -CsvPath ".\users.csv" -LicenseSku "M365_A1_STUDENT" -DryRun

# Real run
.\MS_add_user_assign_license.ps1 -CsvPath ".\users.csv" -LicenseSku "M365_A1_STUDENT"

#------------------------------------------------------------
# HOW TO FIND THE CORRECT LICENSE SKU
#------------------------------------------------------------
# Connect to Graph:
#   Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All"
# List SKUs:
#   Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId, PrepaidUnits
# Example output:
#   SkuPartNumber             SkuId
#   -------------             -----
#   M365_A1_STUDENT           12345678-abcd-1234-abcd-123456abcdef
# Use either SkuPartNumber or SkuId in $LicenseSku
#------------------------------------------------------------

# Example CSV format
# UserPrincipalName,DisplayName,GivenName,Surname
# alice@student.subschool.nz,Alice Example,Alice,Example
# bob@student.subschool.nz,Bob Test,Bob,Test
#------------------------------------------------------------

param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [Parameter(Mandatory)]
    [string]$LicenseSku,

    # Dry-run mode (preview only)
    [switch]$DryRun,

    # Suppress mailbox creation (disable Exchange service plans)
    [switch]$NoMailbox,

    # Default usage location (required for license assignment)
    [string]$DefaultUsageLocation = "NZ"
)

# Map DryRun for compatibility with -WhatIf
if ($WhatIf) { $DryRun = $true }

Write-Host "DryRun mode: $DryRun" -ForegroundColor Cyan

# Install/import Graph modules
if (-not (Get-Module -ListAvailable Microsoft.Graph)) { Install-Module Microsoft.Graph -Scope CurrentUser -Force }
Import-Module Microsoft.Graph.Users

# Connect to Graph
Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All"

# Load CSV
if (-not (Test-Path $CsvPath)) { throw "CSV file not found: $CsvPath" }
$users = Import-Csv $CsvPath
if ($users.Count -eq 0) { Write-Warning "CSV is empty"; exit }

# Resolve license SKU
$skuInfo = Get-MgSubscribedSku | Where-Object { $_.SkuId -eq $LicenseSku -or $_.SkuPartNumber -eq $LicenseSku }
if (-not $skuInfo) { throw "License SKU '$LicenseSku' not found. Run Get-MgSubscribedSku" }

Write-Host "Using license: $($skuInfo.SkuPartNumber)" -ForegroundColor Green

# Identify Exchange plans to disable if requested
$disabledPlans = @()
if ($NoMailbox -and $skuInfo.ServicePlans) {
    $disabledPlans = $skuInfo.ServicePlans | Where-Object { $_.ServicePlanName -match "EXCHANGE" } | Select-Object -ExpandProperty ServicePlanId
}

# Process each user
foreach ($u in $users) {

    Write-Host "Processing $($u.UserPrincipalName)" -ForegroundColor Yellow

    # Check if user exists
    $user = Get-MgUser -UserId $u.UserPrincipalName -ErrorAction SilentlyContinue
    if ($user) {
        Write-Warning "User already exists. Skipping creation: $($u.UserPrincipalName)"
    } else {
        $passwordProfile = @{
            Password = [System.Web.Security.Membership]::GeneratePassword(12,3)
            ForceChangePasswordNextSignIn = $true
        }

        if ($DryRun) {
            Write-Host "DRY-RUN: Would create user $($u.UserPrincipalName)"
        } else {
            $user = New-MgUser -AccountEnabled $true `
                -DisplayName $u.DisplayName `
                -GivenName $u.GivenName `
                -Surname $u.Surname `
                -UserPrincipalName $u.UserPrincipalName `
                -MailNickname ($u.UserPrincipalName.Split("@")[0]) `
                -PasswordProfile $passwordProfile
            Write-Host "Created user: $($u.UserPrincipalName)"
        }
    }

    # Set UsageLocation if not present
    $usageLocation = if ($u.UsageLocation) { $u.UsageLocation } else { $DefaultUsageLocation }
    if (-not $DryRun) { Update-MgUser -UserId $user.Id -UsageLocation $usageLocation }
    Write-Host "UsageLocation set: $usageLocation"

    # Assign license
    if ($DryRun) {
        Write-Host "DRY-RUN: Would assign license $($skuInfo.SkuPartNumber) to $($u.UserPrincipalName) (Mailbox disabled: $NoMailbox)"
    } else {
        $assignBody = @{
            addLicenses = @(@{ SkuId = $skuInfo.SkuId; DisabledPlans = $disabledPlans })
            removeLicenses = @()
        }
        Set-MgUserLicense -UserId $user.Id -BodyParameter $assignBody
        Write-Host "License assigned: $($u.UserPrincipalName) (Mailbox disabled: $NoMailbox)"
    }

    Start-Sleep -Milliseconds 200
}

Write-Host "`nCompleted." -ForegroundColor Green
