Connect-MgGraph -Scopes "User.ReadWrite.All"
$csvFile = ".\students.csv"
$students = Import-Csv $csvFile

foreach ($s in $students) {
    $upn = $s.Email
    $existingUser = Get-MgUser -UserId $upn -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        New-MgUser -DisplayName "$($s.'First Name') $($s.'Last Name')" `
            -UserPrincipalName $upn `
            -MailNickname ($upn.Split("@")[0]) `
            -GivenName $s.'First Name' `
            -Surname $s.'Last Name' `
            -AccountEnabled $true `
            -PasswordProfile @{ Password = $s.Password; ForceChangePasswordNextSignIn = $true }

        Write-Host "Created $upn with password from CSV"
    } else {
        Write-Host "User already exists: $upn"
    }
}
