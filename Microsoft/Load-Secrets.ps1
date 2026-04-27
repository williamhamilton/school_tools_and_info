function Get-RepoConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = (Join-Path $PSScriptRoot "secrets.config.local.psd1")
    )

    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Config file not found at '$ConfigPath'. Copy Microsoft/secrets.config.example.psd1 to Microsoft/secrets.config.local.psd1 and fill in your values."
    }

    return Import-PowerShellDataFile -Path $ConfigPath
}

function Resolve-RequiredValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if (-not $Config.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace([string]$Config[$Key])) {
        throw "Missing required config value '$Key'."
    }

    return $Config[$Key]
}

function Get-GraphClientSecretPlainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    $secretName = Resolve-RequiredValue -Config $Config -Key "ClientSecretName"

    # Prefer SecretManagement vault; fall back to env var only when configured.
    if (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue) {
        try {
            $secretValue = Get-Secret -Name $secretName -ErrorAction Stop -AsPlainText
            if (-not [string]::IsNullOrWhiteSpace($secretValue)) {
                return $secretValue
            }
        }
        catch {
            # Continue to optional environment variable fallback.
        }
    }

    if ($Config.ContainsKey("ClientSecretEnvVar") -and -not [string]::IsNullOrWhiteSpace([string]$Config.ClientSecretEnvVar)) {
        $envValue = [Environment]::GetEnvironmentVariable([string]$Config.ClientSecretEnvVar)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            return $envValue
        }
    }

    throw "Could not resolve client secret '$secretName'. Set it with Set-Secret, or configure ClientSecretEnvVar with a populated environment variable."
}

