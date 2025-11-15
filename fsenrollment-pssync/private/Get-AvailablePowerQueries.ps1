#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to get available PowerQueries from PowerSchool.

.DESCRIPTION
    Retrieves the list of available PowerQueries from the PowerSchool schema endpoint.
    Parses the response and returns a clean list of PowerQuery names.

.OUTPUTS
    String[]. Array of available PowerQuery names.

.NOTES
    This is a private helper function used by Invoke-PowerQuery.
#>
function Get-AvailablePowerQueries {
    [CmdletBinding()]
    param()

    $token = Get-PowerSchoolAccessToken
    $headers = @{
        'Authorization' = "Bearer $token"
        'Accept' = 'application/json'
    }

    $uri = "$script:PowerSchoolBaseUrl/ws/schema/query/api"
    
    Write-Verbose "Retrieving available PowerQueries from: $uri"
    
    try {
        $result = Invoke-PowerSchoolApiRequest -Uri $uri -Headers $headers -Method 'Get'
        
        # Parse PowerQuery names from the response
        $queriesString = $result | Out-String
        $queryMatches = [regex]::Matches($queriesString, 'powerquery\.(resp|param)\.([^=;]+)')
        
        $parsedQueries = @()
        foreach ($match in $queryMatches) {
            $queryName = $match.Groups[2].Value
            if ($queryName -and $queryName -notmatch '^record\.' -and $queryName -notmatch '^\s*$') {
                $parsedQueries += $queryName
            }
        }
        
        $uniqueQueries = $parsedQueries | Sort-Object -Unique
        Write-Verbose "Found $($uniqueQueries.Count) unique PowerQueries"
        
        return $uniqueQueries
    }
    catch {
        Write-Error "Failed to retrieve available PowerQueries: $($_.Exception.Message)"
        throw
    }
}