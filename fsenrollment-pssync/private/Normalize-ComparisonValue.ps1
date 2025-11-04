#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to normalize values for comparison.

.DESCRIPTION
    Normalizes values for consistent comparison between CSV and PowerSchool data.
    Handles null values, empty strings, whitespace, and type conversions.

.PARAMETER Value
    The value to normalize.

.OUTPUTS
    The normalized value (string, number, or $null).

.NOTES
    This is a private function used internally for data comparison.
#>
function Normalize-ComparisonValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    # Handle null or empty values
    if ($null -eq $Value) {
        return $null
    }

    # Handle strings
    if ($Value -is [string]) {
        $trimmed = $Value.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            return $null
        }
        return $trimmed
    }

    # Handle numbers (convert to string for consistent comparison)
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [decimal] -or $Value -is [double]) {
        return $Value.ToString()
    }

    # Handle booleans
    if ($Value -is [bool]) {
        return $Value.ToString().ToLower()
    }

    # Handle datetime (should be handled separately, but just in case)
    if ($Value -is [datetime]) {
        return $Value.ToString('yyyy-MM-dd')
    }

    # Default: convert to string
    return $Value.ToString().Trim()
}
