#Requires -Version 7.0

<#
.SYNOPSIS
    Execute PowerSchool PowerQuery with custom parameters.

.DESCRIPTION
    Executes a PowerSchool PowerQuery with optional parameters and returns the results.
    Validates that the PowerQuery exists before attempting to execute it unless explicitly
    skipped. Supports listing available PowerQueries and returning raw JSON responses.
    Uses the established PowerSchool connection from Connect-PowerSchool.

.PARAMETER PowerQueryName
    The name of the PowerQuery to execute (e.g., "com.scs.dats.students.contacts.email").

.PARAMETER Arguments
    PowerShell hashtable or object containing arguments to pass to the PowerQuery.
    Will be automatically converted to JSON format for the API request.

.PARAMETER ListAvailable
    List all available PowerQueries and return them as an array of strings.

.PARAMETER SkipExistenceCheck
    Skip checking if the PowerQuery exists in the available list.
    Useful for testing custom PowerQueries or when the list endpoint is unavailable.

.PARAMETER ShowRawResponse
    Include the raw JSON response in the output object for debugging purposes.

.PARAMETER AllRecords
    Retrieve all records using pagination. This automatically handles paging through
    all available results beyond the default page size limit (typically 100 records).

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    PSCustomObject. Contains the PowerQuery results with properties:
    - QueryName: The name of the executed PowerQuery
    - RecordCount: Number of records returned
    - Records: Array of result records
    - RawResponse: Raw JSON response (only if ShowRawResponse is used)
    
    When ListAvailable is used, returns string array of available PowerQuery names.

.EXAMPLE
    Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.contacts.email"
    
    Executes the email contacts PowerQuery and returns formatted results.

.EXAMPLE
    Invoke-PowerQuery -PowerQueryName "com.scs.dats.dataversion_contactchanges_lookup" -Arguments @{id = "12345"}
    
    Executes a PowerQuery with specific parameters.

.EXAMPLE
    Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.bygrade" -Arguments @{gradeLevel = "12"}
    
    Executes a PowerQuery to get students by grade level.

.EXAMPLE
    $availableQueries = Invoke-PowerQuery -ListAvailable
    
    Gets a list of all available PowerQueries.

.EXAMPLE
    Invoke-PowerQuery -PowerQueryName "com.custom.powerquery" -SkipExistenceCheck
    
    Executes a custom PowerQuery without validating its existence first.

.EXAMPLE
    Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.contacts.email" -AllRecords
    
    Retrieves all email contact records using pagination to get beyond the default limit.

.EXAMPLE
    $result = Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.contacts.email" -ShowRawResponse
    $result.RawResponse  # Access raw JSON for debugging
    
    Executes PowerQuery and includes raw JSON response for debugging.

.NOTES
    This function requires an active PowerSchool connection established via Connect-PowerSchool.
    PowerQuery names should be the full dotted notation as they appear in PowerSchool.
    The function implements retry logic through the underlying Invoke-PowerSchoolApiRequest function.

.LINK
    Connect-PowerSchool
#>
function Invoke-PowerQuery {
    [CmdletBinding(DefaultParameterSetName = 'Execute')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Execute')]
        [string]$PowerQueryName,

        [Parameter(Mandatory = $false, ParameterSetName = 'Execute')]
        [object]$Arguments,

        [Parameter(Mandatory = $true, ParameterSetName = 'List')]
        [switch]$ListAvailable,

        [Parameter(Mandatory = $false, ParameterSetName = 'Execute')]
        [switch]$SkipExistenceCheck,

        [Parameter(Mandatory = $false, ParameterSetName = 'Execute')]
        [switch]$ShowRawResponse,

        [Parameter(Mandatory = $false, ParameterSetName = 'Execute')]
        [switch]$AllRecords
    )

    # Ensure PowerSchool connection is active
    if (-not $script:PowerSchoolBaseUrl) {
        throw "PowerSchool connection not established. Use Connect-PowerSchool first."
    }

    Write-Verbose "PowerQuery operation requested for: $($PowerQueryName ?? 'List Available')"

    try {
        # Handle listing available PowerQueries
        if ($ListAvailable) {
            Write-Verbose "Retrieving list of available PowerQueries"
            $availableQueries = Get-AvailablePowerQueries
            return $availableQueries
        }

        # Validate PowerQuery exists (unless skipped)
        if (-not $SkipExistenceCheck) {
            Write-Verbose "Validating PowerQuery existence: $PowerQueryName"
            $availableQueries = Get-AvailablePowerQueries
            
            if (-not (Test-PowerQueryExists -PowerQueryName $PowerQueryName -AvailableQueries $availableQueries)) {
                throw "PowerQuery '$PowerQueryName' was not found in the available PowerQueries list. Use -SkipExistenceCheck to bypass this validation."
            }
            Write-Verbose "PowerQuery validation successful"
        }
        else {
            Write-Verbose "Skipping PowerQuery existence check"
        }

        # Execute the PowerQuery
        Write-Verbose "Executing PowerQuery: $PowerQueryName"
        
        if ($AllRecords) {
            Write-Verbose "Retrieving all records using pagination"
            
            # Get total count first
            $totalCount = Get-PowerQueryRecordCount -PowerQueryName $PowerQueryName -ArgumentsObject $Arguments
            Write-Verbose "Total records available: $totalCount"
            
            if ($totalCount -eq 0) {
                Write-Verbose "No records to retrieve"
                [System.Collections.ArrayList]$allRecords = @()
            }
            else {
                # Use standard page size of 100 (PowerSchool default)
                $pageSize = 100
                $totalPages = [Math]::Ceiling($totalCount / $pageSize)
                Write-Verbose "Will retrieve $totalPages pages of $pageSize records each"
                
                [System.Collections.ArrayList]$allRecords = @()
                
                for ($page = 1; $page -le $totalPages; $page++) {
                    Write-Verbose "Retrieving page $page of $totalPages"
                    
                    $pageResult = Invoke-PowerQueryExecution -PowerQueryName $PowerQueryName -ArgumentsObject $Arguments -PageNumber $page -PageSize $pageSize
                    
                    if ($pageResult -and $pageResult.PSObject.Properties.Name -contains 'record' -and $pageResult.record) {
                        $allRecords.AddRange($pageResult.record)
                        Write-Verbose "Added $($pageResult.record.Count) records from page $page"
                    }
                }
                
                Write-Verbose "Retrieved total of $($allRecords.Count) records across $totalPages pages"
            }
            
            # Create response object for paginated results
            $response = [PSCustomObject]@{
                QueryName = $PowerQueryName
                RecordCount = $allRecords.Count
                Records = [array]$allRecords
                TotalRecords = $totalCount
                PaginationUsed = $true
            }
        }
        else {
            # Single page execution (existing behavior)
            $result = Invoke-PowerQueryExecution -PowerQueryName $PowerQueryName -ArgumentsObject $Arguments
            
            # Format the response
            $response = [PSCustomObject]@{
                QueryName = $PowerQueryName
                RecordCount = 0
                Records = @()
                PaginationUsed = $false
            }

            # Extract records and count
            if ($result -and $result.PSObject.Properties.Name -contains 'record' -and $result.record) {
                $response.Records = $result.record
                $response.RecordCount = $result.record.Count
            }
            elseif ($result -and $result.PSObject.Properties.Name -contains 'count') {
                $response.RecordCount = $result.count
                if ($result.PSObject.Properties.Name -contains 'record') {
                    $response.Records = $result.record
                }
            }
            
            # Include raw response if requested (only for single page)
            if ($ShowRawResponse) {
                $response | Add-Member -NotePropertyName 'RawResponse' -NotePropertyValue $result
            }
        }

        Write-Verbose "PowerQuery executed successfully. Records returned: $($response.RecordCount)"
        return $response
    }
    catch {
        Write-Error "PowerQuery operation failed: $($_.Exception.Message)"
        throw
    }
}