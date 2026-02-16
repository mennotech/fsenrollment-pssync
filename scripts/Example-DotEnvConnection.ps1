#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates connecting to PowerSchool using .env file credentials.

.DESCRIPTION
    This example shows how Connect-PowerSchool now automatically loads credentials
    from the config/.env file when available, making it easier to work with the
    PowerSchool API during development.

.NOTES
    Prerequisites:
    1. Create config/.env file from config/.env.example
    2. Fill in your PowerSchool credentials in config/.env
    3. Ensure config/.env is not committed to git (it's in .gitignore)
#>

# Import the module
$ModuleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $ModuleRoot 'fsenrollment-pssync' 'FSEnrollment-PSSync.psd1') -Force

Write-Host "`n=== Connect-PowerSchool with .env File ===" -ForegroundColor Cyan
Write-Host "This example demonstrates automatic credential loading from .env file`n" -ForegroundColor Gray

# Check if .env file exists
$envFilePath = Join-Path $ModuleRoot 'config' '.env'
if (-not (Test-Path $envFilePath)) {
    Write-Host "ERROR: .env file not found!" -ForegroundColor Red
    Write-Host "Please create it from the example:" -ForegroundColor Yellow
    Write-Host "  Copy-Item config\.env.example config\.env" -ForegroundColor Yellow
    Write-Host "  Then edit config\.env with your actual credentials`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found .env file at: $envFilePath" -ForegroundColor Green

# Connect to PowerSchool - no parameters needed!
# It will automatically load credentials from .env file
Write-Host "`nConnecting to PowerSchool using .env credentials..." -ForegroundColor Cyan

try {
    Connect-PowerSchool -Verbose
    
    Write-Host "`n✓ Successfully connected!" -ForegroundColor Green
    Write-Host "`nCredential Loading Priority:" -ForegroundColor Cyan
    Write-Host "  1. Explicit parameters (highest priority)" -ForegroundColor Gray
    Write-Host "  2. .env file credentials" -ForegroundColor Gray
    Write-Host "  3. Environment variables" -ForegroundColor Gray
    Write-Host "  4. Interactive prompts (lowest priority)`n" -ForegroundColor Gray
    
    Write-Host "Connection successful! You can now use PowerSchool API functions." -ForegroundColor Green
}
catch {
    Write-Host "`n✗ Connection failed: $_" -ForegroundColor Red
    Write-Host "`nPlease verify your .env file contains valid credentials:" -ForegroundColor Yellow
    Write-Host "  - POWERSCHOOL_URL" -ForegroundColor Yellow
    Write-Host "  - POWERSCHOOL_CLIENT_ID" -ForegroundColor Yellow
    Write-Host "  - POWERSCHOOL_CLIENT_SECRET`n" -ForegroundColor Yellow
}

Write-Host "`nYou can also override .env credentials with explicit parameters:" -ForegroundColor Cyan
Write-Host '  Connect-PowerSchool -BaseUrl "https://other.powerschool.com"' -ForegroundColor Gray
Write-Host "`nOr force reconnection:" -ForegroundColor Cyan
Write-Host "  Connect-PowerSchool -Force`n" -ForegroundColor Gray
