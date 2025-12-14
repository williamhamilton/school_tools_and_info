<#
__author__ = "William Hamilton"
__python__ = ""
__created__ = "12/12/2025"
__copyright__ = "Copyright © 2025~"
__license__ = ""
__ToDo__ = """
- nothing to add just yet

.SYNOPSIS
Assign Microsoft 365 licenses to existing users, optionally disable Exchange service plans (prevent mailbox creation), and handle proxyAddress/Contact conflicts.

.DESCRIPTION
This script is focused on assigning licenses to existing Azure AD users from a CSV input. It does NOT create new user objects.
Key behaviors:
  - Looks up a subscribed SKU by SkuId (GUID) or SkuPartNumber and assigns it to each user in the CSV.
  - When the CreateMailbox switch is false the script will place Exchange-related ServicePlanIds (matching ServicePlanName containing "EXCHANGE" or "EXO") into DisabledPlans so Exchange/Exchange Online is not provisioned.
  - Detects proxyAddress conflicts (other users or contacts already owning the SMTP address) and will skip those users (or warn) to avoid collisions.
  - Optionally deletes conflicting Contacts (when run without -DryRun the script issues a Graph DELETE for the contact found).
  - Supports Dry-run (preview) mode where no mutating Graph calls are performed; actions are printed instead.

PARAMETERS
  -CsvPath (string, mandatory): Path to input CSV. The script reads this file and processes each row.
  -LicenseSku (string): The SKU identifier to assign. Can be a SkuPartNumber (human-friendly like "M365_A1_FACULTY") or the SkuId GUID. If empty the script will not assign licenses.
  -FixedPassword (string): Optional fixed password to set in the passwordProfile if you were creating users. NOTE: this script currently operates on existing users and does not create users; the parameter is left for compatibility or future creation logic.
  -CreateMailbox (bool): When $false (default in some flows) the script disables Exchange service plans on the license assignment. When $true Exchange is left enabled.
  -DefaultUsageLocation (string): UsageLocation to set on users before assigning licenses (e.g., NZ, AU, US). Used when a row does not include UsageLocation.
  -DryRun (switch): If present the script will only print intended actions and not perform Graph mutating calls.
  -WhatIf (switch): Alias for DryRun. Setting -WhatIf toggles DryRun on.

INPUT CSV FORMAT
At minimum the CSV must include a UserPrincipalName column. Optional columns supported by the script include UsageLocation, DisplayName, GivenName, Surname depending on which fields you want to update.
Example minimal CSV (comma separated):
  UserPrincipalName,UsageLocation
  alice@yourdomain.nz,NZ
  bob@yourdomain.nz,

PREREQUISITES / PERMISSIONS
  - PowerShell (pwsh) with the Microsoft.Graph module installed. The script will attempt to install the module if missing.
  - The signed-in account must have permissions to read and modify users, contacts and licenses. Typical delegated scopes required:
      User.ReadWrite.All, Directory.ReadWrite.All
    Admin consent for these scopes is usually required for non-admin users.

HOW LICENSES ARE HANDLED
  - The script resolves the provided $LicenseSku by checking Get-MgSubscribedSku and matching SkuId or SkuPartNumber.
  - If $CreateMailbox is false the script collects the ServicePlanId(s) where the ServicePlanName contains "EXCHANGE" or "EXO" and supplies them in DisabledPlans when calling Set-MgUserLicense. This prevents Exchange mailbox provisioning for newly-licensed users.
  - The script skips users that already have the same SKU assigned.

CONTACT / PROXY ADDRESS BEHAVIOR
  - If a Contact object exists with the same SMTP (mail) as the user UPN the script will attempt to delete the contact before assigning a license (only if not in DryRun).
  - The script also checks for any other User or Contact that already lists the proxyAddresses value 'SMTP:<UPN>' and will skip assignment for that user to avoid address collisions.

EXAMPLES
  # Dry-run preview (no changes):
  pwsh -NoProfile -File ./MS_add_user_assign_license.ps1 -CsvPath ./users.csv -LicenseSku M365_A1_FACULTY -CreateMailbox:$false -DryRun

  # Real run (apply changes):
  pwsh -NoProfile -File ./MS_add_user_assign_license.ps1 -CsvPath ./users.csv -LicenseSku 94763226-9b3c-4e75-a931-5c89701abe66 -CreateMailbox:$false

VERIFICATION
  - Check assigned licenses and disabled plans for a user:
      Get-MgUser -UserId alice@yourdomain.nz -Property AssignedLicenses | Select-Object -ExpandProperty AssignedLicenses
  - If Exchange is expected to be disabled, the AssignedLicenses DisabledPlans array should contain the Exchange ServicePlanId(s).

CAVEATS & SUGGESTED IMPROVEMENTS
  - The script operates on existing users only; if you need user creation, add a creation path and verify password handling.
  - Deleting Contacts is destructive. Ensure you have backups or use DryRun to preview deletions first.
  - Matching ServicePlanName on "EXCHANGE|EXO" works for most SKUs but might miss custom naming; consider expanding to explicit ServicePlanId lists for greater reliability.
  - Consider adding a per-user CreateMailbox column in the CSV to override global behavior.
  - Add structured logging (CSV/JSON) of results and generated passwords (if you later add creation) for an audit trail.


------------------------------------------------------------
 HOW TO FIND THE CORRECT LICENSE SKU
------------------------------------------------------------
1) Connect to Microsoft Graph (admin account):
     Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All"

2) List all subscribed SKUs in your tenant:
     Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId, PrepaidUnits

   Example output:
     SkuPartNumber             SkuId                                 PrepaidUnits
     -------------             -----                                 -----------
     STANDARDWOFFPACK_FACULTY 12345678-abcd-1234-abcd-123456abcdef @{Enabled=500; Suspended=0; Warning=0}
     M365_A1_STUDENT           87654321-abcd-4321-abcd-abcdef654321 @{Enabled=1000; Suspended=0; Warning=0}

3) Use either the **SkuPartNumber** (friendly name) or **SkuId** (GUID) in the script variable:
     [string]$LicenseSku = "STANDARDWOFFPACK_FACULTY"
     OR
     [string]$LicenseSku = "12345678-abcd-1234-abcd-123456abcdef"

Notes:
 - SkuPartNumber is easier to read and maintain in scripts.
 - SkuId is guaranteed unique across tenants.
 - Make sure there are available seats (PrepaidUnits.Enabled > 0) before assigning.

# End of documentation header
#>

param (
    [Parameter(Mandatory)]
    [string]$CsvPath,

    # License SKU Part Number OR GUID (eg A1_STUDENT, A5_STUDENT)
    [string]$LicenseSku = "",

    # Fixed password for all users (optional)
    [string]$FixedPassword = "",

    # Set to $false to suppress Exchange mailbox
    [bool]$CreateMailbox = $false,

    # Default country for licensing (NZ, AU, US etc)
    [string]$DefaultUsageLocation = "NZ",

    # Dry run (no changes)
    [switch]$DryRun,

    # PowerShell-native alias
    [switch]$WhatIf
)


# Map WhatIf to DryRun
if ($WhatIf) { $DryRun = $true }
Write-Host "DryRun mode: $DryRun" -ForegroundColor Cyan

#------------------------------------------------------------
# Install / import Graph module
#------------------------------------------------------------
if (-not (Get-Module -ListAvailable Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Users

#------------------------------------------------------------
# Connect to Graph
#------------------------------------------------------------
Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All"


#------------------------------------------------------------
# Load CSV
#------------------------------------------------------------
if (-not (Test-Path $CsvPath)) { throw "CSV file not found: $CsvPath" }
$users = Import-Csv $CsvPath
if ($users.Count -eq 0) { Write-Warning "CSV is empty"; exit }

#------------------------------------------------------------
# Resolve License SKU once
#------------------------------------------------------------
$skuInfo = $null
$exchangePlans = @()
if ($LicenseSku -ne "") {
    $skuInfo = Get-MgSubscribedSku | Where-Object { $_.SkuId -eq $LicenseSku -or $_.SkuPartNumber -eq $LicenseSku }
    if (-not $skuInfo) { throw "License SKU '$LicenseSku' not found. Run: Get-MgSubscribedSku" }

    Write-Host "Using license: $($skuInfo.SkuPartNumber)" -ForegroundColor Green

    if (-not $CreateMailbox -and $skuInfo.ServicePlans) {
        # Include any EXCHANGE or EXO service plan
        $exchangePlans = $skuInfo.ServicePlans |
            Where-Object { $_.ServicePlanName -match "EXCHANGE|EXO" } |
            Select-Object -ExpandProperty ServicePlanId
    }
}

#------------------------------------------------------------
# Process users
#------------------------------------------------------------
foreach ($u in $users) {
    $upn = $u.UserPrincipalName
    Write-Host "`nProcessing $upn" -ForegroundColor Yellow

    #--------------------------------------------------------
    # Remove conflicting Contacts first
    #--------------------------------------------------------
    $contactConflict = Get-MgContact -Filter "mail eq '$upn'" -ErrorAction SilentlyContinue
    if ($contactConflict) {
        if ($DryRun) {
            Write-Host "DRY-RUN: Would delete Contact $($contactConflict.DisplayName) with email $upn" -ForegroundColor Red
        }
        else {
            Write-Host "Deleting Contact $($contactConflict.DisplayName) with email $upn" -ForegroundColor Red
#             Remove-MgContact -ContactId $contactConflict.Id -Confirm:$false
            if ($DryRun) {
                Write-Host "DRY-RUN: Would delete Contact $($contactConflict.DisplayName) with email $upn" -ForegroundColor Red
            } else {
                Write-Host "Deleting Contact $($contactConflict.DisplayName) with email $upn" -ForegroundColor Red
                Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/contacts/$($contactConflict.Id)"
            }
        }
    }

    #--------------------------------------------------------
    # Get existing user
    #--------------------------------------------------------
    $user = Get-MgUser -UserId $upn -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Warning "User not found in Azure AD: $upn. Skipping."
        continue
    }

    #--------------------------------------------------------
    # Set UsageLocation if needed
    #--------------------------------------------------------
    $usageLocation = if ($u.UsageLocation) { $u.UsageLocation } else { $DefaultUsageLocation }
    if (-not $DryRun) {
        Update-MgUser -UserId $user.Id -UsageLocation $usageLocation
        Write-Host "UsageLocation set: $usageLocation"
    } else {
        Write-Host "DRY-RUN: Would set UsageLocation = $usageLocation for $upn"
    }

    #--------------------------------------------------------
    # Check for proxyAddress conflicts
    #--------------------------------------------------------
    $proxyConflictUser = Get-MgUser -Filter "proxyAddresses/any(c:c eq 'SMTP:$upn')" -ErrorAction SilentlyContinue
    if ($proxyConflictUser -and $proxyConflictUser.Id -ne $user.Id) {
        Write-Warning "Conflict: another object has proxyAddress $upn. Skipping license assignment."
        continue
    }

    $proxyConflictContact = Get-MgContact -Filter "proxyAddresses/any(c:c eq 'SMTP:$upn')" -ErrorAction SilentlyContinue
    if ($proxyConflictContact) {
        Write-Warning "Conflict: a Contact has proxyAddress $upn. Delete manually or rerun with -DryRun to preview deletion."
        continue
    }

    #--------------------------------------------------------
    # Assign license if needed
    #--------------------------------------------------------
    if ($skuInfo) {
        $existingLicenses = $user.AssignedLicenses | Select-Object -ExpandProperty SkuId
        if ($existingLicenses -contains $skuInfo.SkuId) {
            Write-Host "License already assigned for $upn. Skipping."
            continue
        }

        $assign = @{
            addLicenses    = @(@{SkuId = $skuInfo.SkuId; DisabledPlans = $exchangePlans})
            removeLicenses = @()
        }

        if (-not $DryRun) {
            Set-MgUserLicense -UserId $user.Id -BodyParameter $assign
            Write-Host "License assigned with Exchange disabled: $upn"
        } else {
            Write-Host "DRY-RUN: Would assign license with Exchange disabled: $upn"
        }
    } else {
        Write-Warning "No LicenseSku provided; skipping license assignment."
    }

    Start-Sleep -Milliseconds 200
}

Write-Host "`nCompleted." -ForegroundColor Green
