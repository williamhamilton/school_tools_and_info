<#
.SYNOPSIS
    Migrates Microsoft 365 Faculty users from an A5 license to an A3 + Defender
    suite in a single atomic Graph API call.

.DESCRIPTION
    This script connects to Microsoft Graph using a service principal (client
    secret), identifies all users in the tenant who hold an M365 A5 Faculty
    license, and replaces it with an M365 A3 Faculty license plus Microsoft
    Defender — without any gap in service coverage.

    WORKFLOW
    --------
    1. Load configuration and secrets from a local PSD1 file.
    2. Authenticate to Microsoft Graph via client-secret credential.
    3. Pre-flight validation — confirm all three SKU GUIDs exist in the tenant.
    4. Query users whose assignedLicenses include the A5 SKU.
    5. For each user, perform an idempotent atomic swap:
         - AddLicenses    : A3 and/or Defender (only if not already assigned)
         - RemoveLicenses : A5
    6. Export a timestamped CSV migration report next to the script.

    IDEMPOTENCY
    -----------
    Before building the add list, the script checks each user's current assigned
    licenses. If A3 or Defender is already present, it is omitted from the add
    list. A5 is always removed. Re-running the script on the same tenant is safe.

    ATOMIC UPDATE
    -------------
    The add and remove operations are submitted in a single Set-MgUserLicense
    call (one HTTP PATCH to the Graph API). This minimises — but does not
    entirely eliminate — any window where a user temporarily holds neither
    licence.

    GROUP-BASED LICENSING
    ---------------------
    If a user's A5 licence is inherited from an Entra group rather than
    assigned directly, the Graph API will reject the change with an error
    similar to "User licence is inherited from a group". Those users will
    be marked as errors in the report. Handle them by modifying group
    membership in the Entra admin centre or via the Groups API instead.

    PERMISSIONS REQUIRED
    --------------------
    The Azure AD app registration used must have the following
    APPLICATION (not delegated) permissions granted by an admin:
      • User.ReadWrite.All      — read users and modify their licences
      • Organization.Read.All   — read subscribed SKUs for validation

    CONFIGURATION FILE (secrets.config.local.psd1)
    -----------------------------------------------
    The script reads all sensitive values from an external PSD1 file so that
    no secrets are hard-coded. The file must live at $ConfigPath (default:
    same folder as the script) and follow this structure:

        @{
            TenantId     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            ClientId     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            ClientSecret = "your-client-secret-value"   # or use CertThumbprint

            SkuIds = @{
                A5       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # M365 A5 Faculty
                A3       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # M365 A3 Faculty
                Defender = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Microsoft Defender
            }
        }

    To find your tenant's SKU GUIDs, run after connecting interactively:
        Connect-MgGraph -Scopes "Organization.Read.All"
        Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId

    HELPER DEPENDENCY
    -----------------
    The script dot-sources Load-Secrets.ps1 from the same directory. That
    module must expose three functions:
      • Get-RepoConfig              : imports and returns the PSD1 as a hashtable
      • Resolve-RequiredValue       : extracts a key or throws if missing
      • Get-GraphClientSecretPlainText : retrieves the plaintext client secret

    PREREQUISITES
    -------------
    Install the Microsoft Graph PowerShell SDK (once, per machine):
        Install-Module Microsoft.Graph -Scope CurrentUser

    Minimum required sub-modules:
        Microsoft.Graph.Authentication
        Microsoft.Graph.Users
        Microsoft.Graph.Identity.DirectoryManagement

.PARAMETER ConfigPath
    Full path to the PSD1 secrets/configuration file.
    Defaults to "secrets.config.local.psd1" in the same directory as the script.

.PARAMETER WhatIfOnly
    When specified, the script performs all read and validation steps but does
    NOT call Set-MgUserLicense. Each user is logged as "Simulated" in the
    report. Use this flag for a safe dry run before applying changes to
    production.

    NOTE: This is a custom switch, not the built-in PowerShell $WhatIfPreference
    mechanism, so it will not propagate to called cmdlets automatically.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    CSV file — written to the script directory as:
        MigrationReport_<yyyyMMdd_HHmm>.csv

    Columns:
        Timestamp         — Date/time the row was processed (yyyy-MM-dd HH:mm:ss)
        DisplayName       — User's display name in Entra ID
        UserPrincipalName — User's UPN / login address
        Status            — Success | Simulated | Error: <message>
        Additions         — Semicolon-separated list of SKU GUIDs that were added
                            (empty if both A3 and Defender were already present)

.EXAMPLE
    # Dry run — no changes applied, report shows what would happen
    .\Migrate-M365FacultyLicenses.ps1 -WhatIfOnly

.EXAMPLE
    # Live run with default config path
    .\Migrate-M365FacultyLicenses.ps1

.EXAMPLE
    # Live run pointing to a config file in a different location
    .\Migrate-M365FacultyLicenses.ps1 -ConfigPath "C:\Secrets\prod.config.psd1"

.EXAMPLE
    # Combine a custom config path with a dry run
    .\Migrate-M365FacultyLicenses.ps1 -ConfigPath "C:\Secrets\prod.config.psd1" -WhatIfOnly

.NOTES
    Author       : IT Administration
    Version      : 2.0.0
    Last Updated : 2025

    CHANGE LOG
    ----------
    2.0.0 - Added idempotency check, atomic swap, pre-flight validation,
            group-licence error guidance, and comprehensive documentation.
    1.0.0 - Initial release.

    RELATED LINKS
    -------------
    Microsoft Graph — Set-MgUserLicense:
        https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users/set-mguserlicense

    Microsoft Graph — assignedLicenses:
        https://learn.microsoft.com/en-us/graph/api/user-assignlicense

    Group-based licensing in Entra ID:
        https://learn.microsoft.com/en-us/entra/identity/users/licensing-groups-assign
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "secrets.config.local.psd1"),

    [Parameter(Mandatory = $false)]
    [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"


# ──────────────────────────────────────────────────────────────────────────────
# FUNCTION: Normalise-SkuId
# ──────────────────────────────────────────────────────────────────────────────
function Normalize-SkuId {
    <#
    .SYNOPSIS
        Normalises a SKU GUID string to lowercase with hyphens.

    .DESCRIPTION
        Casts the input to [guid] (which validates format) then returns the
        canonical lowercase, hyphenated representation. This ensures consistent
        string comparisons when checking whether a SKU is already assigned to a
        user, regardless of the casing returned by different Graph endpoints.

    .PARAMETER SkuId
        The raw SKU GUID string to normalise. Must be a valid GUID.

    .OUTPUTS
        [string] — lowercase GUID, e.g. "6fd2c87f-b296-42f0-b197-1e91e994b900"

    .EXAMPLE
        Normalize-SkuId -SkuId "6FD2C87F-B296-42F0-B197-1E91E994B900"
        # Returns: "6fd2c87f-b296-42f0-b197-1e91e994b900"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkuId
    )

    try {
        return ([guid]$SkuId).Guid.ToLowerInvariant()
    }
    catch {
        throw "Invalid SkuId '$SkuId'. Expected a GUID value."
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# DEPENDENCY: Load helper functions from Load-Secrets.ps1
# ──────────────────────────────────────────────────────────────────────────────
. (Join-Path $PSScriptRoot "Load-Secrets.ps1")

# Accumulates one row per processed user; exported to CSV at the end.
$Report = @()

try {
    # 1. Load Configuration
    $config = Get-RepoConfig -ConfigPath $ConfigPath
    $tenantId = Resolve-RequiredValue -Config $config -Key "TenantId"
    $clientId = Resolve-RequiredValue -Config $config -Key "ClientId"
    $clientSecretPlainText = Get-GraphClientSecretPlainText -Config $config

    if (-not $config.ContainsKey("SkuIds")) {
        throw "Missing required 'SkuIds' block in config file."
    }

    $A5_SkuId = Normalize-SkuId -SkuId (Resolve-RequiredValue -Config $config.SkuIds -Key "A5")
    $A3_SkuId = Normalize-SkuId -SkuId (Resolve-RequiredValue -Config $config.SkuIds -Key "A3")
    $Defender_SkuId = Normalize-SkuId -SkuId (Resolve-RequiredValue -Config $config.SkuIds -Key "Defender")

    # Authentication
    $secureSecret = ConvertTo-SecureString -String $clientSecretPlainText -AsPlainText -Force
    $clientSecretCredential = [System.Management.Automation.PSCredential]::new($clientId, $secureSecret)

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Gray
    Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $clientSecretCredential -NoWelcome

    # Validation Check (Pre-Flight)
    # Confirms all required SKUs exist in the tenant before touching users.
    Write-Host "Validating SKUs in tenant..." -ForegroundColor Gray
    $subscribedSkus = Get-MgSubscribedSku | ForEach-Object { Normalize-SkuId -SkuId ([string]$_.SkuId) }

    $requiredSkus = @($A5_SkuId, $A3_SkuId, $Defender_SkuId)
    foreach ($sku in $requiredSkus) {
        if ($sku -notin $subscribedSkus) {
            throw "Validation Failed: SkuId '$sku' was not found in this tenant. Please check your secrets.config.local.psd1."
        }
    }
    Write-Host "Validation successful. All SKUs found.`n" -ForegroundColor Green

    # Query users with an A5 licence
    # The server-side OData filter limits results to relevant users only.
    # AssignedLicenses is requested explicitly as it is not returned by default.
    $filter = "assignedLicenses/any(x:x/skuId eq $A5_SkuId)"
    $Users = Get-MgUser -Filter $filter -All -Property Id, DisplayName, UserPrincipalName, AssignedLicenses

    Write-Host "--- M365 FACULTY LICENSE MIGRATION ---" -ForegroundColor Cyan
    Write-Host "Found $($Users.Count) users with A5 licenses." -ForegroundColor White
    if ($WhatIfOnly) { Write-Host "[MODE: WHAT-IF ONLY - No changes will be applied]`n" -ForegroundColor Yellow }

    if (-not $Users -or $Users.Count -eq 0) {
        Write-Host "No users matched the A5 filter. No changes required." -ForegroundColor Yellow
    }

    # Process each user
    foreach ($User in $Users) {
        $Status = "Pending"

        # Determine exactly what needs to be added (Idempotency)
        # Normalise the user's current SKUs and build the add list only for
        # licences not already present. This makes the script safe to re-run.
        $currentSkus = $User.AssignedLicenses | ForEach-Object { Normalize-SkuId -SkuId $_.SkuId }
        $addList = @()

        if ($A3_SkuId -notin $currentSkus) { $addList += @{ SkuId = $A3_SkuId } }
        if ($Defender_SkuId -notin $currentSkus) { $addList += @{ SkuId = $Defender_SkuId } }

        # Build the atomic change object
        # Submitting both AddLicenses and RemoveLicenses in one call minimises
        # the window where the user holds neither A5 nor A3.
        $LicenseChange = @{
            AddLicenses    = $addList
            RemoveLicenses = @($A5_SkuId)
        }

        if ($WhatIfOnly) {
            $msg = "WHATIF: Would migrate $($User.DisplayName)"
            if ($addList.Count -eq 0) { $msg += " (Removal only - A3/Defender already present)" }
            Write-Host $msg -ForegroundColor Yellow
            $Status = "Simulated"
        }
        else {
            try {
                Set-MgUserLicense -UserId $User.Id -BodyParameter $LicenseChange
                Write-Host "SUCCESS: $($User.DisplayName)" -ForegroundColor Green
                $Status = "Success"
            }
            catch {
                # Capture the error but continue processing remaining users.
                # Common failure: user's A5 is group-inherited - I should capture that specific error and provide guidance in the report.
                $errorMessage = $_.Exception.Message
                Write-Host "FAILED: $($User.DisplayName) - $errorMessage" -ForegroundColor Red
                $Status = "Error: $errorMessage"
            }
        }

        $Report += [PSCustomObject]@{
            Timestamp         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            Status            = $Status
            Additions         = ($addList.SkuId -join "; ")
        }
    }

    # Reporting
    $ReportPath = Join-Path $PSScriptRoot "MigrationReport_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
    $Report | Export-Csv -Path $ReportPath -NoTypeInformation

    Write-Host "`n--- Migration Complete ---" -ForegroundColor Cyan
    Write-Host "Log file saved to: $ReportPath" -ForegroundColor Gray
}
finally {
    # Always disconnect from Graph, even if an unhandled error occurred above.
    if (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue) {
        $mgContext = Get-MgContext
        if ($null -ne $mgContext) {
            Disconnect-MgGraph
        }
    }
}