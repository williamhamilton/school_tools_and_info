@{
    # Azure AD tenant and app registration values.
    TenantId         = "00000000-0000-0000-0000-000000000000"
    ClientId         = "00000000-0000-0000-0000-000000000000"

    # Name of the secret in SecretManagement/SecretStore.
    ClientSecretName = "GraphClientSecret"

    # Optional fallback env var name if Get-Secret is unavailable.
    ClientSecretEnvVar = "GRAPH_CLIENT_SECRET"

    # SKU IDs for the migration script.
    SkuIds = @{
        A5       = "00000000-0000-0000-0000-000000000000"
        A3       = "00000000-0000-0000-0000-000000000000"
        Defender = "00000000-0000-0000-0000-000000000000"
    }
}

