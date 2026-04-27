# Microsoft Script Secrets Setup

Use this setup so secrets stay out of source control while scripts can still run locally.

## 1) Create your local config file

Copy `Microsoft/secrets.config.example.psd1` to `Microsoft/secrets.config.local.psd1`, then fill in:

- `TenantId`
- `ClientId`
- `SkuIds.A5`, `SkuIds.A3`, `SkuIds.Defender`

Do not put real client secrets in this file.

## 2) Store the client secret locally (recommended)

Install SecretManagement and SecretStore once:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name LocalVault -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```

Save the app secret using the same name as `ClientSecretName` in your config:

```powershell
Set-Secret -Name GraphClientSecret -Secret (Read-Host "Client secret" -AsSecureString)
```

## 3) Optional environment variable fallback

If you are not using SecretManagement, set the environment variable named by `ClientSecretEnvVar`:

```powershell
$env:GRAPH_CLIENT_SECRET = "your-client-secret"
```

## 4) Run the migration script

```powershell
pwsh ./Microsoft/product_a5_to_a3_with_defender.ps1
```

Use preview mode first:

```powershell
pwsh ./Microsoft/product_a5_to_a3_with_defender.ps1 -WhatIfOnly
```

