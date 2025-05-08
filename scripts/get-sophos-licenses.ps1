# Get environment variables
$clientId     = $env:SOPHOS_CLIENT_ID
$clientSecret = $env:SOPHOS_CLIENT_SECRET
$tenantId     = $env:SOPHOS_TENANT_ID
$outputFile   = $env:OUTPUT_FILE

# Authenticate with Sophos API
$authBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "token"
}

try {
    $authResponse = Invoke-RestMethod -Uri "https://id.sophos.com/api/v2/oauth2/token" -Method Post -Body $authBody -ContentType "application/x-www-form-urlencoded"
    $bearerToken = $authResponse.access_token
} catch {
    Write-Error "Failed to authenticate with Sophos API: $_"
    exit 1
}

# Get tenant info and API host
try {
    $whoamiResponse = Invoke-RestMethod -Uri "https://api.central.sophos.com/whoami/v1" -Method Get -Headers @{
        "Authorization" = "Bearer $bearerToken"
    }

    $tenantId = if ($tenantId) { $tenantId } else { $whoamiResponse.id }
    $apiHost  = $whoamiResponse.apiHosts.dataRegion
} catch {
    Write-Error "Failed to retrieve tenant information: $_"
    exit 1
}

# Get license info using correct API host
try {
    $licenseResponse = Invoke-RestMethod -Uri "https://$apiHost/endpoint/v1/licenses" -Method Get -Headers @{
        "Authorization" = "Bearer $bearerToken"
        "X-Tenant-ID"   = $tenantId
    }

    # Format the output
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
    $outputDir = Split-Path -Path $outputFile
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory | Out-Null
    }

    # Export to CSV
    $licenseData | Export-Csv -Path $outputFile -NoTypeInformation
    Write-Output "✅ License data exported to $outputFile"
} catch {
    Write-Error "❌ Failed to fetch license data: $_"
    exit 1
}
