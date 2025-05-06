# Get environment variables
$clientId = $env:SOPHOS_CLIENT_ID
$clientSecret = $env:SOPHOS_CLIENT_SECRET
$tenantId = $env:SOPHOS_TENANT_ID
$outputFile = $env:OUTPUT_FILE

# Authenticate with Sophos API
$authBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "token"
}

$authResponse = Invoke-RestMethod -Uri "https://id.sophos.com/api/v2/oauth2/token" -Method Post -Body $authBody -ContentType "application/x-www-form-urlencoded"
$bearerToken = $authResponse.access_token

# Get tenant information if not provided
if (-not $tenantId) {
    $whoamiResponse = Invoke-RestMethod -Uri "https://api.central.sophos.com/whoami/v1" -Method Get -Headers @{
        "Authorization" = "Bearer $bearerToken"
    }
    $tenantId = $whoamiResponse.id
}

# Get license information
$licenseResponse = Invoke-RestMethod -Uri "https://api.central.sophos.com/endpoint/v1/licenses" -Method Get -Headers @{
    "Authorization" = "Bearer $bearerToken"
    "X-Tenant-ID"   = $tenantId
}

# Process license data
$licenseData = $licenseResponse.items | Select-Object type, status, @{
    Name = 'totalDevices'; Expression = { $_.quantity }
}, @{
    Name = 'usedLicenses'; Expression = { $_.used }
}, @{
    Name = 'availableLicenses'; Expression = { $_.quantity - $_.used }
}, @{
    Name = 'reportDate'; Expression = { Get-Date -Format "yyyy-MM-dd" }
}

# Export to CSV
$licenseData | Export-Csv -Path $outputFile -NoTypeInformation

Write-Output "License data exported to $outputFile"
