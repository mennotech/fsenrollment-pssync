<#
.SYNOPSIS
    Example script demonstrating secure credential loading and usage.

.DESCRIPTION
    This script demonstrates how to securely load credentials from environment
    variables or .env file, use them for API calls, and properly clean up
    sensitive data after use.

.NOTES
    This is an example script. In production, you would use these techniques
    within your actual sync scripts.
#>

# Import the module
Import-Module "$PSScriptRoot\..\fsenrollment-pssync\FSEnrollment-PSSync.psd1" -Force

# Option 1: Load credentials from .env file (development)
Write-Host "Loading credentials from environment..." -ForegroundColor Cyan
$credentials = Import-EnvironmentCredentials -Verbose

# Display what was loaded (non-sensitive data only)
Write-Host "`nLoaded configuration:" -ForegroundColor Green
if ($credentials.PowerSchoolUrl) {
    Write-Host "  PowerSchool URL: $($credentials.PowerSchoolUrl)"
}
if ($credentials.SftpHost) {
    Write-Host "  SFTP Host: $($credentials.SftpHost)"
}
if ($credentials.LogLevel) {
    Write-Host "  Log Level: $($credentials.LogLevel)"
}

# Check if we have credentials loaded
if ($credentials.PowerSchoolClientId) {
    Write-Host "`nSecure credentials loaded (stored as SecureStrings)" -ForegroundColor Green
    
    # Example: Use credentials for API call
    # In real usage, you would decrypt only when needed:
    <#
    $clientId = ConvertFrom-SecureCredential -SecureString $credentials.PowerSchoolClientId
    $clientSecret = ConvertFrom-SecureCredential -SecureString $credentials.PowerSchoolClientSecret
    
    try {
        # Make API call
        $authResponse = Invoke-RestMethod -Uri "$($credentials.PowerSchoolUrl)/oauth/token" `
            -Method Post `
            -Body @{
                client_id = $clientId
                client_secret = $clientSecret
                grant_type = 'client_credentials'
            }
        
        Write-Host "API authentication successful!" -ForegroundColor Green
    }
    finally {
        # CRITICAL: Always clear plaintext credentials immediately after use
        $clientId = $null
        $clientSecret = $null
        
        # Force garbage collection
        [System.GC]::Collect()
    }
    #>
    
    Write-Host "`nCredentials are encrypted in memory and ready to use." -ForegroundColor Yellow
}
else {
    Write-Host "`nNo credentials loaded. Create a .env file from .env.example" -ForegroundColor Yellow
    Write-Host "Location: $PSScriptRoot\..\config\.env" -ForegroundColor Yellow
}

# Option 2: Production usage with environment variable clearing
Write-Host "`n--- Production Example ---" -ForegroundColor Cyan
Write-Host "In production, load and immediately clear environment variables:" -ForegroundColor White
Write-Host @"

# Load from environment variables (no .env file in production)
`$credentials = Import-EnvironmentCredentials ``
    -EnvFilePath `$null ``
    -ClearEnvironmentVariables ``
    -Verbose

# Credentials are now:
# 1. Loaded into memory as SecureStrings
# 2. Environment variables cleared
# 3. Safe from memory dumps or environment inspection

"@ -ForegroundColor Gray

Write-Host "`nSecurity Best Practices:" -ForegroundColor Cyan
Write-Host "  ✓ Use .env files for local development (never commit them)" -ForegroundColor Green
Write-Host "  ✓ Use environment variables in production VMs" -ForegroundColor Green
Write-Host "  ✓ Clear environment variables after loading (-ClearEnvironmentVariables)" -ForegroundColor Green
Write-Host "  ✓ Decrypt SecureStrings only when needed for API calls" -ForegroundColor Green
Write-Host "  ✓ Clear plaintext variables immediately after use" -ForegroundColor Green
Write-Host "  ✓ Run security tests before committing code" -ForegroundColor Green

Write-Host "`nRun security tests:" -ForegroundColor Cyan
Write-Host "  Invoke-Pester -Path .\fsenrollment-pssync\tests\Security.CredentialLeak.Tests.ps1" -ForegroundColor White
