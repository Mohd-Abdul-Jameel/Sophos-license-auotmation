# Example structure for your PowerShell script
$clientId = $env:SOPHOS_CLIENT_ID
$clientSecret = $env:SOPHOS_CLIENT_SECRET

# Authenticate with Sophos API
$auth = Invoke-RestMethod -Uri "https://id.sophos.com/api/v2/oauth2/token" -Method Post -Body @{
    "grant_type" = "client_credentials"
    "client_id" = $clientId
    "client_secret" = $clientSecret
    "scope" = "token"
}
$token = $auth.access_token

# Get license information
$headers = @{
    "Authorization" = "Bearer $token"
    "X-Tenant-ID" = "your-tenant-id"
}
$licenses = Invoke-RestMethod -Uri "https://api.central.sophos.com/endpoint/v1/licenses" -Headers $headers

# Process and export to CSV
$licenses | Export-Csv -Path "./sophos_licenses.csv" -NoTypeInformation
