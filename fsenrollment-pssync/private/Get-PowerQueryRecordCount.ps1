#Requires -Version 7.0

<#
.SYNOPSIS
    Get the total record count for a PowerSchool PowerQuery.

.DESCRIPTION
    Makes an API call to the PowerSchool /count endpoint to retrieve the total
    number of records that would be returned by a PowerQuery. This is useful
    for implementing pagination.

.PARAMETER PowerQueryName
    The name of the PowerQuery to get the count for.

.PARAMETER ArgumentsObject
    The arguments to pass to the PowerQuery for counting.

.OUTPUTS
    Integer. The total number of records available.

.NOTES
    This is a private helper function used by Invoke-PowerQuery for pagination.
#>
function Get-PowerQueryRecordCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PowerQueryName,

        [Parameter(Mandatory = $false)]
        [object]$ArgumentsObject
    )

    $token = Get-PowerSchoolAccessToken
    $headers = @{
        'Authorization' = "Bearer $token"
        'Accept' = 'application/json'
        'Content-Type' = 'application/json'
    }

    $uri = "$script:PowerSchoolBaseUrl/ws/schema/query/$PowerQueryName/count"
    
    # Prepare request body (same as regular query)
    $body = if ($null -eq $ArgumentsObject) { 
        '{}' 
    } 
    else { 
        try {
            $ArgumentsObject | ConvertTo-Json -Depth 5 -Compress
        }
        catch {
            throw "Failed to convert Arguments to JSON: $($_.Exception.Message)"
        }
    }
    
    Write-Verbose "Getting record count at URI: $uri"
    Write-Verbose "Request body: $body"
    
    try {
        $result = Invoke-PowerSchoolApiRequest -Uri $uri -Headers $headers -Method 'Post' -Body $body
        
        if ($result -and $result.PSObject.Properties.Name -contains 'count') {
            Write-Verbose "Record count retrieved: $($result.count)"
            return $result.count
        }
        else {
            Write-Warning "Count endpoint did not return expected 'count' property"
            return 0
        }
    }
    catch {
        Write-Error "Failed to get PowerQuery record count: $($_.Exception.Message)"
        throw
    }
}