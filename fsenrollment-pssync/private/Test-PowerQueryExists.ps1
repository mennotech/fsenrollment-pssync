#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to check if a PowerQuery exists in the available list.

.DESCRIPTION
    Validates that a specific PowerQuery name exists in the list of available PowerQueries.
    Uses multiple patterns to match PowerQuery names in different formats.

.PARAMETER PowerQueryName
    The PowerQuery name to search for.

.PARAMETER AvailableQueries
    The list of available PowerQueries to search within.

.OUTPUTS
    Boolean. True if the PowerQuery exists, false otherwise.

.NOTES
    This is a private helper function used by Invoke-PowerQuery.
#>
function Test-PowerQueryExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PowerQueryName,

        [Parameter(Mandatory = $true)]
        [string[]]$AvailableQueries
    )
    
    # Check if the PowerQuery name exists in the available list
    $exists = $AvailableQueries -contains $PowerQueryName
    
    Write-Verbose "PowerQuery existence check for '$PowerQueryName': $exists"
    return $exists
}