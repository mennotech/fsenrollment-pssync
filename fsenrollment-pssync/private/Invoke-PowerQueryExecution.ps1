#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to execute a PowerSchool PowerQuery.

.DESCRIPTION
    Makes the actual API call to execute a PowerQuery with the specified arguments.
    Handles JSON conversion and error responses.

.PARAMETER PowerQueryName
    The name of the PowerQuery to execute.

.PARAMETER ArgumentsObject
    The arguments to pass to the PowerQuery.

.PARAMETER PageNumber
    The page number to retrieve (1-based). Optional.

.PARAMETER PageSize
    The number of records per page. Optional.

.OUTPUTS
    PSCustomObject. The raw response from the PowerQuery execution.

.NOTES
    This is a private helper function used by Invoke-PowerQuery.
#>
function Invoke-PowerQueryExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PowerQueryName,

        [Parameter(Mandatory = $false)]
        [object]$ArgumentsObject,

        [Parameter(Mandatory = $false)]
        [int]$PageNumber,

        [Parameter(Mandatory = $false)]
        [int]$PageSize
    )

    $token = Get-PowerSchoolAccessToken
    $headers = @{
        'Authorization' = "Bearer $token"
        'Accept' = 'application/json'
        'Content-Type' = 'application/json'
    }

    $uri = "$script:PowerSchoolBaseUrl/ws/schema/query/$PowerQueryName"
    
    # Add pagination parameters if specified
    $queryParams = @()
    if ($PageNumber -gt 0) {
        $queryParams += "page=$PageNumber"
    }
    if ($PageSize -gt 0) {
        $queryParams += "pagesize=$PageSize"
    }
    
    if ($queryParams.Count -gt 0) {
        $uri += "?" + ($queryParams -join "&")
    }
    
    # Prepare request body
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
    
    Write-Verbose "Executing PowerQuery at URI: $uri"
    Write-Verbose "Request body: $body"
    
    try {
        $result = Invoke-PowerSchoolApiRequest -Uri $uri -Headers $headers -Method 'Post' -Body $body
        Write-Verbose "PowerQuery execution completed successfully"
        return $result
    }
    catch {
        Write-Error "PowerQuery execution failed: $($_.Exception.Message)"
        throw
    }
}