# Get environment variables
$clientId = $env:SOPHOS_CLIENT_ID
$clientSecret = $env:SOPHOS_CLIENT_SECRET
$tenantId = $env:SOPHOS_TENANT_ID
$outputFile = $env:OUTPUT_FILE

if (-not $clientId -or -not $clientSecret) {
    Write-Error "Client ID or Secret not set."
    exit 1
}

# Authenticate with Sophos API
$authBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "token"
}

try {
    $authResponse = Invoke-RestMethod -Uri "https://id.sophos.com/api/v2/oauth2/token" -Method Post -Body $authBody -ContentType "application/x-www-form-urlencoded"
} catch {
    Write-Error "Authentication failed: $_"
    exit 1
}

$bearerToken = $authResponse.access_token

# Get tenant ID if not passed
if (-not $tenantId) {
    try {
        $whoamiResponse = Invoke-RestMethod -Uri "https://api.central.sophos.com/whoami/v1" -Method Get -Headers @{
            "Authorization" = "Bearer $bearerToken"
        }
        $tenantId = $whoamiResponse.id
    } catch {
        Write-Error "Failed to fetch tenant ID: $_"
        exit 1
    }
}

# Get license info
try {
    $licenseResponse = Invoke-RestMethod -Uri "https://api.central.sophos.com/endpoint/v1/licenses" -Method Get -Headers @{
        "Authorization" = "Bearer $bearerToken"
        "X-Tenant-ID"   = $tenantId
    }
} catch {
    Write-Error "Failed to fetch license data: $_"
    exit 1
}

# Format the data
$licenseData = $licenseResponse.items | Select-Object type, status, @{
    Name = 'totalDevices'; Expression = { $_.quantity }
}, @{
    Name = 'usedLicenses'; Expression = { $_.used }
}, @{
    Name = 'availableLicenses'; Expression = { $_.quantity - $_.used }
}, @{
    Name = 'reportDate'; Expression = { Get-Date -Format "yyyy-MM-dd" }
}

# Ensure output directory exists
$outputDir = Split-Path -Parent $outputFile
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Export to CSV
$licenseData | Export-Csv -Path $outputFile -NoTypeInformation

Write-Output "✅ License data exported to $outputFile"
