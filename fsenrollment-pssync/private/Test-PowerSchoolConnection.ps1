#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to ensure PowerSchool session is authenticated and token is valid.

.DESCRIPTION
    Checks if the PowerSchool session is authenticated and the token is still valid.
    If the token is expired or will expire soon (within 5 minutes), automatically
    refreshes it. Throws an error if not connected.

.PARAMETER RefreshThresholdMinutes
    Number of minutes before expiry to trigger automatic token refresh. Default is 5.

.OUTPUTS
    None. Refreshes the token if needed.

.NOTES
    This is a private function used internally by other PowerSchool API functions.
#>
function Test-PowerSchoolConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$RefreshThresholdMinutes = 5
    )

    Write-Verbose "Checking PowerSchool connection status"

    # Check if connected
    if (-not $script:PowerSchoolToken -or -not $script:PowerSchoolBaseUrl) {
        throw "Not connected to PowerSchool. Please run Connect-PowerSchool first."
    }

    # Check if token needs refresh
    $now = Get-Date
    $refreshThreshold = $now.AddMinutes($RefreshThresholdMinutes)

    if ($script:PowerSchoolTokenExpiry -le $refreshThreshold) {
        Write-Verbose "Token expired or expiring soon. Refreshing token..."
        
        # Store current base URL to avoid prompting
        $currentBaseUrl = $script:PowerSchoolBaseUrl
        
        # Reconnect to refresh token
        Connect-PowerSchool -BaseUrl $currentBaseUrl -ClientId $script:PowerSchoolClientId -ClientSecret $script:PowerSchoolClientSecret -Force
        
        Write-Verbose "Token refreshed successfully"
    } else {
        Write-Verbose "Token is valid until $($script:PowerSchoolTokenExpiry)"
    }
}
