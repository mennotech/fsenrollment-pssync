<#
.SYNOPSIS
    Simple standalone PowerQuery testing script

.DESCRIPTION
    Test script to execute PowerSchool PowerQueries with custom parameters.
    Uses environment variables for authentication, with parameter fallback support.
    Validates that the PowerQuery exists before attempting to execute it.
    
    Smart Credential Requirements:
    - ServerName is always required (to identify which cached token to use)
    - ClientId and ClientSecret are only required if no valid cached token exists
    - If credentials are not found, the script will prompt for them interactively
    - Once authenticated, subsequent runs only need the ServerName
    
    Credential Resolution Order:
    1. Environment variables (PowerSchoolClientID, PowerSchoolClientSecret, PowerSchoolServer)
    2. Script parameters (-ClientId, -ClientSecret, -ServerName)
    3. Interactive prompts (secure input for Client Secret)

.PARAMETER PowerQueryName
    The name of the PowerQuery to execute (e.g., "com.scs.dats.students.contacts.email")

.PARAMETER Arguments
    PowerShell hashtable or object containing arguments to pass to the PowerQuery (optional)

.PARAMETER ClientId
    PowerSchool API Client ID. Used if PowerSchoolClientID environment variable is not set.
    If not provided and no cached token exists, script will prompt for input.

.PARAMETER ClientSecret
    PowerSchool API Client Secret. Used if PowerSchoolClientSecret environment variable is not set.
    If not provided and no cached token exists, script will prompt for secure input.

.PARAMETER ServerName
    PowerSchool server hostname (e.g., 'your-school.powerschool.com'). Used if PowerSchoolServer environment variable is not set.
    Always required to identify which server/token to use. Will prompt if not provided.

.PARAMETER ShowRawResponse
    Display the raw JSON response from the API

.PARAMETER ListAvailable
    List all available PowerQueries and exit

.PARAMETER SkipExistenceCheck
    Skip checking if the PowerQuery exists in the available list (useful for testing)

.PARAMETER ReturnData
    Return the PowerQuery results as an object instead of displaying them. Useful for capturing data in a variable for further processing.

.EXAMPLE
    # Interactive mode - script will prompt for missing credentials
    .\Test-PowerQuery.ps1 -PowerQueryName "com.scs.dats.students.contacts.email"
    # Script will prompt for: Server name, Client ID, and Client Secret (secure input)

.EXAMPLE
    # First run - provide full credentials
    .\Test-PowerQuery.ps1 -ClientId "your-client-id" -ClientSecret "your-secret" -ServerName "your-school.powerschool.com" -PowerQueryName "com.scs.dats.students.contacts.email"

.EXAMPLE
    # Subsequent runs - only server name needed (uses cached token)
    .\Test-PowerQuery.ps1 -ServerName "your-school.powerschool.com" -PowerQueryName "com.scs.dats.students.bygrade" -Arguments @{gradeLevel = "12"}

.EXAMPLE
    # Using environment variables (preferred method)
    $env:PowerSchoolClientID = "your-client-id"
    $env:PowerSchoolClientSecret = "your-client-secret"
    $env:PowerSchoolServer = "your-school.powerschool.com"
    .\Test-PowerQuery.ps1 -PowerQueryName "com.scs.dats.students.contacts.email"

.EXAMPLE
    .\Test-PowerQuery.ps1 -PowerQueryName "com.scs.dats.dataversion_contactchanges_lookup" -Arguments @{id = "12345"}

.EXAMPLE
    # Using parameters (when environment variables are not set)
    .\Test-PowerQuery.ps1 -ClientId "your-client-id" -ClientSecret "your-secret" -ServerName "your-school.powerschool.com" -PowerQueryName "com.scs.dats.students.contacts.email"

.EXAMPLE
    # Using parameters with custom PowerQuery
    .\Test-PowerQuery.ps1 -ClientId "your-id" -ClientSecret "your-secret" -ServerName "your-school.powerschool.com" -PowerQueryName "com.custom.powerquery" -SkipExistenceCheck

.EXAMPLE
    # List available PowerQueries using parameters
    .\Test-PowerQuery.ps1 -ClientId "your-id" -ClientSecret "your-secret" -ServerName "your-school.powerschool.com" -ListAvailable

.EXAMPLE
    # Return data as object for further processing
    $results = .\Test-PowerQuery.ps1 -PowerQueryName "com.scs.dats.students.contacts.email" -ReturnData

.EXAMPLE
    # Working with returned data
    $results = .\Test-PowerQuery.ps1 -PowerQueryName "com.scs.dats.students.contacts.email" -ReturnData
    $results.record.Count # Gets count: 100
    $results.record[0] # Gets first record
    $results.record[0].student_id # Gets specific field value
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$PowerQueryName,
    
    [Parameter(Mandatory=$false)]
    [object]$Arguments,
    
    [Parameter(Mandatory=$false)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$false)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    
    [switch]$ShowRawResponse,
    
    [switch]$ListAvailable,
    
    [switch]$SkipExistenceCheck,
    
    [switch]$ReturnData
)

Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Get API credentials from environment variables or parameters
$ResolvedClientId = if ([string]::IsNullOrWhiteSpace($env:PowerSchoolClientID)) { $ClientId } else { $env:PowerSchoolClientID }
$ResolvedClientSecret = if ([string]::IsNullOrWhiteSpace($env:PowerSchoolClientSecret)) { $ClientSecret } else { $env:PowerSchoolClientSecret }
$ResolvedServerName = if ([string]::IsNullOrWhiteSpace($env:PowerSchoolServer)) { $ServerName } else { $env:PowerSchoolServer }

# Always require ServerName since we need it to check for cached tokens
if ([string]::IsNullOrWhiteSpace($ResolvedServerName)) {
    Write-Host "PowerSchool Server not found in environment variables or parameters." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Example server formats:" -ForegroundColor Cyan
    Write-Host "  your-school.powerschool.com" -ForegroundColor Gray
    Write-Host "  ps.yourschooldistrict.org" -ForegroundColor Gray
    Write-Host ""
    $ResolvedServerName = Read-Host "Please enter your PowerSchool server hostname"
    if ([string]::IsNullOrWhiteSpace($ResolvedServerName)) {
        Write-Error "Server name is required to connect to PowerSchool API."
        exit 1
    }
}

# Check if we have a valid cached token
$tokenKey = "PSToken_$($ResolvedServerName.Replace('.', '_').Replace('/', '_'))"
$hasValidToken = $false

if (Get-Variable -Name $tokenKey -Scope Global -ErrorAction SilentlyContinue) {
    try {
        $cachedToken = Get-Variable -Name $tokenKey -Scope Global -ValueOnly -ErrorAction SilentlyContinue
        if ($cachedToken -and $cachedToken.expires_at -gt (Get-Date)) {
            $hasValidToken = $true
            Write-Verbose "Found valid cached token (expires: $($cachedToken.expires_at))"
        }
    } 
    catch { 
        Write-Verbose "Cached token check failed: $($_.Exception.Message)"
    }
}

# Only require credentials if we don't have a valid token
if (-not $hasValidToken) {
    if ([string]::IsNullOrWhiteSpace($ResolvedClientId)) {
        Write-Host "PowerSchool Client ID not found in environment variables or parameters." -ForegroundColor Yellow
        Write-Host ""
        $ResolvedClientId = Read-Host "Please enter your PowerSchool Client ID"
        if ([string]::IsNullOrWhiteSpace($ResolvedClientId)) {
            Write-Error "Client ID is required to authenticate with PowerSchool API."
            exit 1
        }
    }

    if ([string]::IsNullOrWhiteSpace($ResolvedClientSecret)) {
        Write-Host "PowerSchool Client Secret not found in environment variables or parameters." -ForegroundColor Yellow
        Write-Host ""
        $secureSecret = Read-Host "Please enter your PowerSchool Client Secret" -AsSecureString
        $ResolvedClientSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret))
        if ([string]::IsNullOrWhiteSpace($ResolvedClientSecret)) {
            Write-Error "Client Secret is required to authenticate with PowerSchool API."
            exit 1
        }
    }
    
    Write-Host ""
    Write-Host "Tip: To avoid entering credentials repeatedly, set environment variables:" -ForegroundColor Cyan
    Write-Host '  $env:PowerSchoolClientID = "your-client-id"' -ForegroundColor Gray
    Write-Host '  $env:PowerSchoolClientSecret = "your-client-secret"' -ForegroundColor Gray
    Write-Host '  $env:PowerSchoolServer = "your-server.powerschool.com"' -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Verbose "Using cached token, credentials not required for this run"
}

function Get-PowerSchoolAccessToken {
    <#
    .SYNOPSIS
        Get OAuth access token for PowerSchool API
    #>
    Param(
        [Parameter(Mandatory=$false)][string]$ClientId,
        [Parameter(Mandatory=$false)][string]$ClientSecret,
        [Parameter(Mandatory=$true)][string]$ServerName
    )

    # Check for cached token in global variable
    $tokenKey = "PSToken_$($ServerName.Replace('.', '_').Replace('/', '_'))"
    
    if (Get-Variable -Name $tokenKey -Scope Global -ErrorAction SilentlyContinue) {
        try {
            $cachedToken = Get-Variable -Name $tokenKey -Scope Global -ValueOnly -ErrorAction SilentlyContinue
            if ($cachedToken -and $cachedToken.expires_at -gt (Get-Date)) {
                Write-Verbose "Using cached token (expires: $($cachedToken.expires_at))"
                return $cachedToken.access_token
            }
        } 
        catch { 
            Write-Warning "Failed to read cached token: $($_.Exception.Message)"
        }
    }

    # If we reach here, we need to request a new token
    if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ClientSecret)) {
        throw "No valid cached token found and credentials (ClientId/ClientSecret) are required to obtain a new token"
    }

    # Request new token
    Write-Verbose "Requesting new access token from $ServerName"
    $authCode = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${ClientId}:${ClientSecret}"))
    $headers = @{ 
        "Authorization" = "Basic ${authCode}"
        "Content-Type" = "application/x-www-form-urlencoded;charset=UTF-8" 
    }
    
    try {
        $resp = Invoke-RestMethod -Method Post -Headers $headers -Uri "https://${ServerName}/oauth/access_token/" -Body "grant_type=client_credentials"
        if (-not $resp.access_token) { 
            throw "No access token in response" 
        }
        
        # Cache token with expiry in global variable
        $expiresAt = (Get-Date).AddSeconds([int]$resp.expires_in - 60) # Subtract 60 seconds for safety margin
        $tokenData = @{
            access_token = $resp.access_token
            token_type = $resp.token_type
            expires_at = $expiresAt
        }
        Set-Variable -Name $tokenKey -Value $tokenData -Scope Global
        
        Write-Verbose "Successfully obtained new access token"
        return $resp.access_token
    }
    catch {
        Write-Error "Failed to obtain access token: $($_.Exception.Message)"
        throw
    }
}

function Get-AvailablePowerQueries {
    <#
    .SYNOPSIS
        Get list of available PowerQueries from PowerSchool
    #>
    Param(
        [Parameter(Mandatory=$true)][string]$ServerName,
        [Parameter(Mandatory=$true)][string]$AccessToken
    )

    $headers = @{ 
        "Authorization" = "Bearer ${AccessToken}"
        "Accept" = "application/json"
    }

    $uri = "https://${ServerName}/ws/schema/query/api"
    
    try {
        Write-Verbose "Retrieving available PowerQueries from: $uri"
        $result = Invoke-RestMethod -Method Get -Headers $headers -Uri $uri
        return $result
    }
    catch {
        Write-Error "Failed to get PowerQueries list: $($_.Exception.Message)"
        throw
    }
}

function Test-PowerQueryExists {
    <#
    .SYNOPSIS
        Check if a specific PowerQuery exists
    #>
    Param(
        [Parameter(Mandatory=$true)][string]$PowerQueryName,
        [Parameter(Mandatory=$true)]$AvailableQueries
    )
    
    # Convert the available queries to string for searching
    $queriesString = $AvailableQueries | Out-String
    
    # Check if the PowerQuery name exists in the response
    # The format appears to be like "powerquery.resp.com.scs.dats.students.bygrade=;"
    # or "powerquery.param.com.scs.dats.students.bygrade=;"
    $patterns = @(
        "powerquery\.resp\.$([regex]::Escape($PowerQueryName))",
        "powerquery\.param\.$([regex]::Escape($PowerQueryName))",
        [regex]::Escape($PowerQueryName)
    )
    
    foreach ($pattern in $patterns) {
        if ($queriesString -match $pattern) {
            Write-Verbose "Found PowerQuery using pattern: $pattern"
            return $true
        }
    }
    
    return $false
}

function Invoke-PowerQuery {
    <#
    .SYNOPSIS
        Execute a PowerSchool PowerQuery
    #>
    Param(
        [Parameter(Mandatory=$true)][string]$ServerName,
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$PowerQueryName,
        [object]$ArgumentsObject
    )

    $headers = @{ 
        "Authorization" = "Bearer ${AccessToken}"
        "Accept" = "application/json"
        "Content-Type" = "application/json"
    }

    $uri = "https://${ServerName}/ws/schema/query/${PowerQueryName}"
    
    # Prepare request body
    $body = if ($null -eq $ArgumentsObject) { 
        '{}' 
    } else { 
        # Convert PowerShell object to JSON
        try {
            $ArgumentsObject | ConvertTo-Json -Depth 5 -Compress
        }
        catch {
            Write-Error "Failed to convert Arguments to JSON: $($_.Exception.Message)"
            throw
        }
    }
    
    Write-Host "Executing PowerQuery:" -ForegroundColor Cyan
    Write-Host "  Name: $PowerQueryName" -ForegroundColor Gray
    Write-Host "  URI: $uri" -ForegroundColor Gray
    Write-Host "  Arguments: $body" -ForegroundColor Gray
    
    try {
        $result = Invoke-RestMethod -Method Post -Headers $headers -Uri $uri -Body $body
        Write-Host "PowerQuery executed successfully!" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "PowerQuery execution failed: $($_.Exception.Message)"
        
        # Try to get detailed error response
        if ($_.Exception.Response) {
            try {
                $responseStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($responseStream)
                $responseBody = $reader.ReadToEnd()
                Write-Host "Server Response: $responseBody" -ForegroundColor Red
            }
            catch {
                Write-Warning "Could not read detailed error response"
            }
        }
        throw
    }
}

# Main execution
try {
    Write-Host "PowerSchool PowerQuery Test Tool" -ForegroundColor Yellow
    Write-Host "Server: $ResolvedServerName" -ForegroundColor Cyan
    
    # Redact Client ID for security (show only first 4 and last 4 characters)
    $redactedClientId = if ($ResolvedClientId.Length -gt 8) {
        $ResolvedClientId.Substring(0, 4) + "****" + $ResolvedClientId.Substring($ResolvedClientId.Length - 4, 4)
    } else {
        "****"
    }
    Write-Host "Client ID: $redactedClientId" -ForegroundColor Cyan
    Write-Host ""

    # Get access token
    $accessToken = Get-PowerSchoolAccessToken -ClientId $ResolvedClientId -ClientSecret $ResolvedClientSecret -ServerName $ResolvedServerName
    
    # Get available PowerQueries
    Write-Host "Retrieving available PowerQueries..." -ForegroundColor Yellow
    $availableQueries = Get-AvailablePowerQueries -ServerName $ResolvedServerName -AccessToken $accessToken
    
    if ($ListAvailable) {
        Write-Host "`nAvailable PowerQueries:" -ForegroundColor Green
        
        # Parse the PowerQuery names from the response
        $queriesString = $availableQueries | Out-String
        $queryMatches = [regex]::Matches($queriesString, 'powerquery\.(resp|param)\.([^=;]+)')
        
        $parsedQueries = @()
        foreach ($match in $queryMatches) {
            $queryName = $match.Groups[2].Value
            if ($queryName -and $queryName -notmatch '^record\.' -and $queryName -notmatch '^\s*$') {
                $parsedQueries += $queryName
            }
        }
        
        if ($parsedQueries.Count -gt 0) {
            $parsedQueries | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            Write-Host "`nTotal PowerQueries found: $($parsedQueries.Count)" -ForegroundColor Cyan
        } else {
            Write-Host "Raw response:" -ForegroundColor Yellow
            $availableQueries | Format-List
        }
        exit 0
    }
    
    if ([string]::IsNullOrWhiteSpace($PowerQueryName)) {
        Write-Error "PowerQueryName parameter is required. Use -ListAvailable to see available PowerQueries."
        exit 1
    }
    
    # Check if PowerQuery exists
    if (-not $SkipExistenceCheck) {
        Write-Host "Checking if PowerQuery exists..." -ForegroundColor Yellow
        $queryExists = Test-PowerQueryExists -PowerQueryName $PowerQueryName -AvailableQueries $availableQueries
        
        if (-not $queryExists) {
            Write-Warning "PowerQuery '$PowerQueryName' was not found in the list of available PowerQueries."
            Write-Host "Use -ListAvailable to see all available PowerQueries or -SkipExistenceCheck to bypass this check." -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "PowerQuery '$PowerQueryName' found. Executing..." -ForegroundColor Green
    } else {
        Write-Host "Skipping existence check. Attempting to execute PowerQuery..." -ForegroundColor Yellow
    }
    
    # Execute PowerQuery
    $result = Invoke-PowerQuery -ServerName $ResolvedServerName -AccessToken $accessToken -PowerQueryName $PowerQueryName -ArgumentsObject $Arguments
    
    # Report record count regardless of ReturnData setting
    Write-Host "`n=== PowerQuery Results ===" -ForegroundColor Green
    if ($result -and $result.PSObject.Properties.Name -contains 'record' -and $result.record) {
        Write-Host "Records returned: $($result.record.Count)" -ForegroundColor Cyan
    } elseif ($result -and $result.PSObject.Properties.Name -contains 'count') {
        Write-Host "Total count: $($result.count)" -ForegroundColor Cyan
    }
    
    # Return data if requested, otherwise display detailed results
    if ($ReturnData) {
        return $result
    }
    
    # Display detailed results
    
    if ($ShowRawResponse) {
        Write-Host "Raw JSON Response:" -ForegroundColor Magenta
        Write-Host ($result | ConvertTo-Json -Depth 10) -ForegroundColor Gray
        Write-Host ""
    }
    
    # Display formatted results (detailed view)
    if ($result -and $result.PSObject.Properties.Name -contains 'record' -and $result.record) {
        if ($result.record.Count -gt 0) {
            $result.record | Format-Table -AutoSize
        }
    } elseif ($result -and $result.PSObject.Properties.Name -contains 'count') {
        if ($result.count -gt 0 -and $result.PSObject.Properties.Name -contains 'record') {
            $result.record | Format-Table -AutoSize
        }
    } else {
        Write-Host "Result structure:" -ForegroundColor Cyan
        $result | Format-List
    }
    
    if (-not $ReturnData) {
        Write-Host "`nPowerQuery test completed successfully!" -ForegroundColor Green
    }
}
catch {
    Write-Error "Test failed: $($_.Exception.Message)"
    exit 1
}