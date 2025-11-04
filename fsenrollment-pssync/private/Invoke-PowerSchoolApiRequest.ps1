#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to invoke PowerSchool API requests with retry logic.

.DESCRIPTION
    Makes HTTP requests to the PowerSchool API with exponential backoff retry logic.
    Handles rate limiting (429), server errors (5xx), and transient network failures.
    Respects Retry-After headers when present.

.PARAMETER Uri
    The API endpoint URI.

.PARAMETER Headers
    Hashtable of HTTP headers.

.PARAMETER Method
    HTTP method (Get, Post, Put, Patch, Delete). Default is Get.

.PARAMETER Body
    Request body for POST/PUT/PATCH requests.

.PARAMETER MaxRetries
    Maximum number of retry attempts. Default is 3.

.PARAMETER InitialRetryDelaySeconds
    Initial retry delay in seconds. Default is 5.

.OUTPUTS
    PSCustomObject. The parsed JSON response from the API.

.NOTES
    This is a private function used internally by PowerSchool API functions.
    Implements exponential backoff: delay doubles on each retry.
#>
function Invoke-PowerSchoolApiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method = 'Get',

        [Parameter(Mandatory = $false)]
        [object]$Body,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$InitialRetryDelaySeconds = 5
    )

    $attempt = 0
    $retryDelay = $InitialRetryDelaySeconds
    $success = $false
    $response = $null

    while (-not $success -and $attempt -le $MaxRetries) {
        try {
            $attempt++
            
            if ($attempt -gt 1) {
                Write-Verbose "Retry attempt $attempt of $MaxRetries"
            }

            $params = @{
                Uri = $Uri
                Headers = $Headers
                Method = $Method
                ErrorAction = 'Stop'
            }

            if ($Body) {
                if ($Body -is [string]) {
                    $params['Body'] = $Body
                } else {
                    $params['Body'] = ($Body | ConvertTo-Json -Depth 10)
                }
            }

            Write-Verbose "$Method request to: $Uri"
            $response = Invoke-RestMethod @params
            $success = $true
            
            return $response
        }
        catch {
            $statusCode = $null
            $retryAfter = $null
            
            # Extract status code and Retry-After header if available
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
                $retryAfter = $_.Exception.Response.Headers['Retry-After']
            }

            $shouldRetry = $false
            
            # Determine if we should retry
            if ($statusCode) {
                # Retry on rate limiting (429) and server errors (5xx)
                if ($statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -lt 600)) {
                    $shouldRetry = $true
                    Write-Warning "Received HTTP $statusCode from PowerSchool API"
                }
            } else {
                # Retry on network errors
                if ($_.Exception.Message -match 'timeout|network|connection') {
                    $shouldRetry = $true
                    Write-Warning "Network error: $($_.Exception.Message)"
                }
            }

            # Check if we have retries left
            if ($shouldRetry -and $attempt -le $MaxRetries) {
                # Use Retry-After header if present, otherwise use exponential backoff
                if ($retryAfter) {
                    # Retry-After can be in seconds or a date
                    if ($retryAfter -match '^\d+$') {
                        $retryDelay = [int]$retryAfter
                    } else {
                        $retryDate = [DateTime]::ParseExact($retryAfter, 'r', [System.Globalization.CultureInfo]::InvariantCulture)
                        $retryDelay = [Math]::Max(1, ($retryDate - (Get-Date)).TotalSeconds)
                    }
                    Write-Verbose "Using Retry-After delay: $retryDelay seconds"
                } else {
                    Write-Verbose "Using exponential backoff delay: $retryDelay seconds"
                }

                Write-Verbose "Waiting $retryDelay seconds before retry..."
                Start-Sleep -Seconds $retryDelay
                
                # Exponential backoff for next attempt
                $retryDelay = $retryDelay * 2
            } else {
                # No more retries or non-retryable error
                Write-Error "PowerSchool API request failed: $_"
                throw
            }
        }
    }

    # If we exit the loop without success, throw
    if (-not $success) {
        throw "PowerSchool API request failed after $MaxRetries retries"
    }
}
