# Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Get credentials from environment variables (set by GitHub Actions)
$clientId = $env:SOPHOS_CLIENT_ID
$clientSecret = $env:SOPHOS_CLIENT_SECRET
$tenantId = $env:SOPHOS_TENANT_ID

# Set headers for token request
$tokenHeaders = @{
    "Content-Type" = "application/x-www-form-urlencoded"
}

# Include client ID and secret in the body
$tokenBody = "grant_type=client_credentials&scope=token&client_id=$clientId&client_secret=$clientSecret"

try {
    Write-Host "Requesting bearer token..."
    $tokenResponse = Invoke-RestMethod -Uri "https://id.sophos.com/api/v2/oauth2/token" -Method Post -Headers $tokenHeaders -Body $tokenBody
    $bearerToken = $tokenResponse.access_token
    
    Write-Host "Token acquired successfully!"

    # Get Licenses Data
    $licenseHeaders = @{
        "Authorization" = "Bearer $bearerToken"
        "Accept" = "application/json"
        "X-Tenant-ID" = $tenantId
    }

    Write-Host "Requesting license data..."
    $licenseResponse = Invoke-RestMethod -Uri "https://api.central.sophos.com/licenses/v1/licenses" -Method Get -Headers $licenseHeaders

    # Create simplified license summary
    $simpleLicenseSummary = @()
    
    foreach ($license in $licenseResponse.licenses) {
        # Handle missing usage.current.count property
        $usedCount = 0
        if ($license.usage -and $license.usage.current -and $license.usage.current.count) {
            $usedCount = $license.usage.current.count
        }
        
        $simpleLicenseSummary += [PSCustomObject]@{
            Date = (Get-Date -Format "yyyy-MM-dd")
            License = $license.product.name
            Total = $license.quantity
            Used = $usedCount
            Available = $license.quantity - $usedCount
            UtilizationPercentage = if ($license.quantity -gt 0) { [math]::Round(($usedCount / $license.quantity) * 100, 2) } else { 0 }
        }
    }

    # Export to CSV file in the repository
    $simpleLicenseSummary | Export-Csv -Path "SophosLicenses.csv" -NoTypeInformation

    Write-Host "License data successfully exported to CSV file!"
}
catch {
    Write-Host "Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}
