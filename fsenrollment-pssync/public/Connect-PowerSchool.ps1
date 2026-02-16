#Requires -Version 7.0

<#
.SYNOPSIS
    Connect to PowerSchool API using OAuth authentication.

.DESCRIPTION
    Establishes an authenticated session with the PowerSchool API using OAuth 2.0.
    The access token is stored securely in a script-scoped variable and automatically
    renewed when it expires. 
    
    Credentials are loaded in the following priority order:
    1. Explicit parameters (BaseUrl, ClientId, ClientSecret)
    2. .env file (via Import-EnvironmentCredentials)
    3. Environment variables (PowerSchool_BaseUrl, PowerSchool_ClientID, PowerSchool_ClientSecret)
    4. Interactive prompts (if none of the above are available)

.PARAMETER BaseUrl
    The base URL for your PowerSchool instance (e.g., 'https://your-instance.powerschool.com').
    If not provided, will attempt to read from .env file, then PowerSchool_BaseUrl environment 
    variable, or prompt if neither is available.

.PARAMETER ClientId
    OAuth Client ID for PowerSchool API access. If not provided, will attempt to read
    from .env file, then PowerSchool_ClientID environment variable, or prompt if neither 
    is available.

.PARAMETER ClientSecret
    OAuth Client Secret for PowerSchool API access. If not provided, will attempt to
    read from .env file, then PowerSchool_ClientSecret environment variable, or prompt 
    if neither is available.

.PARAMETER Force
    Force re-authentication even if already connected.

.OUTPUTS
    None. Sets script-level variables for the authenticated session.

.EXAMPLE
    Connect-PowerSchool
    
    Connects to PowerSchool using credentials from .env file (preferred for local development).

.EXAMPLE
    Connect-PowerSchool -BaseUrl 'https://ps.example.com'
    
    Connects to PowerSchool using the specified URL and credentials from .env file or environment variables.

.EXAMPLE
    Connect-PowerSchool -BaseUrl 'https://ps.example.com' -ClientId 'abc123' -ClientSecret (Read-Host -AsSecureString -Prompt 'Secret')
    
    Connects to PowerSchool with explicit credentials, bypassing .env file and environment variables.

.NOTES
    This function stores the access token in script-scoped variables:
    - $script:PowerSchoolToken (SecureString)
    - $script:PowerSchoolTokenExpiry (DateTime)
    - $script:PowerSchoolBaseUrl (String)
    - $script:PowerSchoolClientId (String)
    - $script:PowerSchoolClientSecret (SecureString)
    
    For local development, create a config/.env file with your credentials:
    - POWERSCHOOL_URL=https://your-instance.powerschool.com
    - POWERSCHOOL_CLIENT_ID=your-client-id
    - POWERSCHOOL_CLIENT_SECRET=your-client-secret
#>
function Connect-PowerSchool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BaseUrl,

        [Parameter(Mandatory = $false)]
        [string]$ClientId,

        [Parameter(Mandatory = $false)]
        [SecureString]$ClientSecret,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-Verbose "Initiating PowerSchool connection"

        # Check if already connected and not forcing reconnection
        if (-not $Force -and $script:PowerSchoolToken -and $script:PowerSchoolTokenExpiry -gt (Get-Date).AddMinutes(5)) {
            Write-Verbose "Already connected to PowerSchool. Token expires at $($script:PowerSchoolTokenExpiry)"
            Write-Host "Already connected to PowerSchool at $script:PowerSchoolBaseUrl" -ForegroundColor Green
            return
        }
    }

    process {
        try {
            # Try to load credentials from .env file if not provided via parameters
            $envCredentials = $null
            if ([string]::IsNullOrWhiteSpace($BaseUrl) -or 
                [string]::IsNullOrWhiteSpace($ClientId) -or 
                $null -eq $ClientSecret) {
                
                try {
                    Write-Verbose "Attempting to load credentials from .env file"
                    $envCredentials = Import-EnvironmentCredentials -ErrorAction SilentlyContinue
                    
                    if ($envCredentials) {
                        Write-Verbose "Successfully loaded credentials from .env file"
                    }
                }
                catch {
                    Write-Debug "Could not load .env credentials: $_"
                }
            }

            # Get BaseUrl from parameter, .env file, environment variable, or prompt
            if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
                if ($envCredentials -and $envCredentials.PowerSchoolUrl) {
                    $BaseUrl = $envCredentials.PowerSchoolUrl
                    Write-Verbose "Using PowerSchool URL from .env file"
                }
                else {
                    $BaseUrl = $env:PowerSchool_BaseUrl
                    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
                        $BaseUrl = Read-Host -Prompt "Enter PowerSchool Base URL (e.g., https://ps.example.com)"
                    }
                }
            }

            # Validate and normalize BaseUrl
            if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
                throw "PowerSchool Base URL is required"
            }
            $BaseUrl = $BaseUrl.TrimEnd('/')

            # Get ClientId from parameter, .env file, environment variable, or prompt
            if ([string]::IsNullOrWhiteSpace($ClientId)) {
                if ($envCredentials -and $envCredentials.PowerSchoolClientId) {
                    # Convert SecureString to plain text
                    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($envCredentials.PowerSchoolClientId)
                    try {
                        $ClientId = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                        Write-Verbose "Using PowerSchool Client ID from .env file"
                    }
                    finally {
                        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                    }
                }
                else {
                    $ClientId = $env:PowerSchool_ClientID
                    if ([string]::IsNullOrWhiteSpace($ClientId)) {
                        $ClientId = Read-Host -Prompt "Enter PowerSchool Client ID"
                    }
                }
            }

            if ([string]::IsNullOrWhiteSpace($ClientId)) {
                throw "PowerSchool Client ID is required"
            }

            # Get ClientSecret from parameter, .env file, environment variable, or prompt
            if ($null -eq $ClientSecret) {
                if ($envCredentials -and $envCredentials.PowerSchoolClientSecret) {
                    $ClientSecret = $envCredentials.PowerSchoolClientSecret
                    Write-Verbose "Using PowerSchool Client Secret from .env file"
                }
                else {
                    $envSecret = $env:PowerSchool_ClientSecret
                    if (-not [string]::IsNullOrWhiteSpace($envSecret)) {
                        $ClientSecret = ConvertTo-SecureString -String $envSecret -AsPlainText -Force
                    } else {
                        $ClientSecret = Read-Host -Prompt "Enter PowerSchool Client Secret" -AsSecureString
                    }
                }
            }

            if ($null -eq $ClientSecret) {
                throw "PowerSchool Client Secret is required"
            }

            # Build OAuth token request (PowerSchool uses trailing slash)
            $tokenUrl = "$BaseUrl/oauth/access_token/"
            Write-Verbose "Requesting access token from: $tokenUrl"

            # Convert SecureString to plain text for API call
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
            try {
                $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                
                # Create base64 encoded credentials for Basic Auth
                $credPair = "${ClientId}:${plainSecret}"
                $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($credPair))
                
                # Prepare headers
                $headers = @{
                    'Authorization' = "Basic $encodedCreds"
                    'Content-Type' = 'application/x-www-form-urlencoded'
                }

                # Request body for client_credentials grant
                $body = 'grant_type=client_credentials'

                # Make the OAuth token request
                $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop

                # Store the access token securely
                $script:PowerSchoolToken = ConvertTo-SecureString -String $response.access_token -AsPlainText -Force
                
                # Calculate token expiry (default to 3600 seconds if not provided)
                $expiresIn = if ($response.expires_in) { $response.expires_in } else { 3600 }
                $script:PowerSchoolTokenExpiry = (Get-Date).AddSeconds($expiresIn)
                
                # Store connection details
                $script:PowerSchoolBaseUrl = $BaseUrl
                $script:PowerSchoolClientId = $ClientId
                $script:PowerSchoolClientSecret = $ClientSecret

                Write-Verbose "Successfully authenticated. Token expires at $($script:PowerSchoolTokenExpiry)"
                Write-Host "Successfully connected to PowerSchool at $BaseUrl" -ForegroundColor Green
            }
            finally {
                # Clear sensitive data from memory
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                if ($plainSecret) {
                    Remove-Variable -Name plainSecret -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Error "Failed to connect to PowerSchool: $_"
            throw
        }
    }

    end {
        Write-Verbose "PowerSchool connection process completed"
    }
}
