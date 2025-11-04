#Requires -Version 7.0

<#
.SYNOPSIS
    Connect to PowerSchool API using OAuth authentication.

.DESCRIPTION
    Establishes an authenticated session with the PowerSchool API using OAuth 2.0.
    The access token is stored securely in a script-scoped variable and automatically
    renewed when it expires. ClientID and ClientSecret can be provided via environment
    variables (PowerSchool_ClientID and PowerSchool_ClientSecret) or will be securely
    requested if not found.

.PARAMETER BaseUrl
    The base URL for your PowerSchool instance (e.g., 'https://your-instance.powerschool.com').
    If not provided, will attempt to read from PowerSchool_BaseUrl environment variable.

.PARAMETER ClientId
    OAuth Client ID for PowerSchool API access. If not provided, will attempt to read
    from PowerSchool_ClientID environment variable or prompt securely.

.PARAMETER ClientSecret
    OAuth Client Secret for PowerSchool API access. If not provided, will attempt to
    read from PowerSchool_ClientSecret environment variable or prompt securely.

.PARAMETER Force
    Force re-authentication even if already connected.

.OUTPUTS
    None. Sets script-level variables for the authenticated session.

.EXAMPLE
    Connect-PowerSchool -BaseUrl 'https://ps.example.com'
    
    Connects to PowerSchool using credentials from environment variables or prompts.

.EXAMPLE
    Connect-PowerSchool -BaseUrl 'https://ps.example.com' -ClientId 'abc123' -ClientSecret (Read-Host -AsSecureString -Prompt 'Secret')
    
    Connects to PowerSchool with explicit credentials.

.NOTES
    This function stores the access token in script-scoped variables:
    - $script:PowerSchoolToken (SecureString)
    - $script:PowerSchoolTokenExpiry (DateTime)
    - $script:PowerSchoolBaseUrl (String)
    - $script:PowerSchoolClientId (String)
    - $script:PowerSchoolClientSecret (SecureString)
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
            # Get BaseUrl from parameter, environment variable, or prompt
            if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
                $BaseUrl = $env:PowerSchool_BaseUrl
                if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
                    $BaseUrl = Read-Host -Prompt "Enter PowerSchool Base URL (e.g., https://ps.example.com)"
                }
            }

            # Validate and normalize BaseUrl
            if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
                throw "PowerSchool Base URL is required"
            }
            $BaseUrl = $BaseUrl.TrimEnd('/')

            # Get ClientId from parameter, environment variable, or prompt
            if ([string]::IsNullOrWhiteSpace($ClientId)) {
                $ClientId = $env:PowerSchool_ClientID
                if ([string]::IsNullOrWhiteSpace($ClientId)) {
                    $ClientId = Read-Host -Prompt "Enter PowerSchool Client ID"
                }
            }

            if ([string]::IsNullOrWhiteSpace($ClientId)) {
                throw "PowerSchool Client ID is required"
            }

            # Get ClientSecret from parameter, environment variable, or prompt
            if ($null -eq $ClientSecret) {
                $envSecret = $env:PowerSchool_ClientSecret
                if (-not [string]::IsNullOrWhiteSpace($envSecret)) {
                    $ClientSecret = ConvertTo-SecureString -String $envSecret -AsPlainText -Force
                } else {
                    $ClientSecret = Read-Host -Prompt "Enter PowerSchool Client Secret" -AsSecureString
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
