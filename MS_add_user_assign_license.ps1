# Install Graph module if needed
if (-not (Get-Module -ListAvailable Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

Import-Module Microsoft.Graph.Users
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Path to CSV
$users = Import-Csv ".\users.csv"

# License SKU ID (example: Microsoft 365 A1 for Students)
# Run: Get-MgSubscribedSku | Select SkuPartNumber, SkuId
$licenseSku = "ENTER-YOUR-SKUID-HERE"   # e.g. "314c4481-f395-4525-be8b-2ec4bb1e9d91"

foreach ($u in $users) {

    $passwordProfile = @{
        Password = [System.Web.Security.Membership]::GeneratePassword(12,3)
        ForceChangePasswordNextSignIn = $true
    }

    # Create user
    $newUser = New-MgUser -AccountEnabled:$true `
        -DisplayName $u.DisplayName `
        -GivenName $u.GivenName `
        -Surname $u.Surname `
        -UserPrincipalName $u.UserPrincipalName `
        -MailNickname ($u.UserPrincipalName.Split("@")[0]) `
        -PasswordProfile $passwordProfile

    Write-Host "Created user: $($u.UserPrincipalName)"

    # Assign license if needed
    if ($licenseSku -ne "") {
        $assign = @{
            addLicenses = @(@{SkuId = $licenseSku})
            removeLicenses = @()
        }

        Set-MgUserLicense -UserId $newUser.Id -BodyParameter $assign
        Write-Host "License assigned to: $($u.UserPrincipalName)"
    }

}
