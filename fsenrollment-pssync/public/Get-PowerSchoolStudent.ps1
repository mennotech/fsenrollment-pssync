#Requires -Version 7.0

<#
.SYNOPSIS
    Retrieves student data from PowerSchool API.

.DESCRIPTION
    Fetches student records from PowerSchool using the PowerSchool API. Can retrieve
    a single student by ID or student number, or all students in the district.
    Supports pagination for large datasets and includes retry logic with exponential backoff.

.PARAMETER DCID
    The PowerSchool internal student database ID (DCID). This is NOT the same as Student_Number.
    DCID is PowerSchool's internal ID and is not typically available from CSV imports.
    Use -StudentNumber parameter instead when working with CSV data.

.PARAMETER StudentNumber
    The student number (returned as 'local_id' in PowerSchool API, stored as 'student_number').
    This is the value from your CSV data. Use this parameter when fetching students from CSV imports.

.PARAMETER All
    Switch to retrieve all students in the district.

.PARAMETER PageSize
    Number of students to retrieve per page when fetching all students. Default is 100.

.PARAMETER Expansions
    Array of expansions to include in the response (e.g., 'demographics', 'addresses', 'phones').

.OUTPUTS
    PSCustomObject or array of PSCustomObjects representing student data from PowerSchool.

.EXAMPLE
    $student = Get-PowerSchoolStudent -StudentNumber '123456'
    
    Retrieves a single student by student number (local_id). This is the recommended approach
    when working with CSV data since Student_Number is available in CSV exports.

.EXAMPLE
    $students = Get-PowerSchoolStudent -All
    
    Retrieves all students in the district.

.EXAMPLE
    $student = Get-PowerSchoolStudent -DCID 12345 -Expansions @('demographics', 'addresses')
    
    Retrieves a student by PowerSchool internal DCID with demographics and addresses expanded.
    Note: DCID is not typically available from CSV imports.

.NOTES
    Requires an active PowerSchool connection via Connect-PowerSchool.
    Implements exponential backoff retry logic for API failures.
#>
function Get-PowerSchoolStudent {
    [CmdletBinding(DefaultParameterSetName = 'ByNumber')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByDCID')]
        [int]$DCID,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByNumber')]
        [string]$StudentNumber,

        [Parameter(Mandatory = $true, ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [ValidateRange(1, 1000)]
        [int]$PageSize = 100,

        [Parameter(Mandatory = $false)]
        [string[]]$Expansions = @()
    )

    begin {
        Write-Verbose "Getting PowerSchool student data"
        
        # Ensure we have a valid connection
        Test-PowerSchoolConnection
        
        # Get access token
        $accessToken = Get-PowerSchoolAccessToken
        
        # Prepare common headers
        $headers = @{
            'Authorization' = "Bearer $accessToken"
            'Accept' = 'application/json'
            'Content-Type' = 'application/json'
        }
    }

    process {
        try {
            $students = @()
            
            switch ($PSCmdlet.ParameterSetName) {
                'ByDCID' {
                    Write-Verbose "Fetching student with DCID: $DCID"
                    $endpoint = "$script:PowerSchoolBaseUrl/ws/v1/student/$DCID"
                    
                    # Add expansions if provided
                    if ($Expansions.Count -gt 0) {
                        $expansionParam = $Expansions -join ','
                        $endpoint += "?expansions=$expansionParam"
                    }
                    
                    $response = Invoke-PowerSchoolApiRequest -Uri $endpoint -Headers $headers -Method Get
                    $students += $response.student
                }
                
                'ByNumber' {
                    Write-Verbose "Fetching student with number: $StudentNumber"
                    
                    # First, get all students and filter (PowerSchool API doesn't have direct student number lookup)
                    # Alternatively, we could use the query endpoint
                    $endpoint = "$script:PowerSchoolBaseUrl/ws/v1/district/student"
                    $queryParams = @("q=student_number==$StudentNumber")
                    
                    if ($Expansions.Count -gt 0) {
                        $queryParams += "expansions=$($Expansions -join ',')"
                    }
                    
                    $endpoint += "?" + ($queryParams -join '&')
                    
                    $response = Invoke-PowerSchoolApiRequest -Uri $endpoint -Headers $headers -Method Get
                    
                    if ($response.students) {
                        $students += $response.students.student
                    }
                }
                
                'All' {
                    Write-Verbose "Fetching all students with page size: $PageSize"
                    
                    $pageNumber = 1
                    $hasMore = $true
                    
                    while ($hasMore) {
                        $endpoint = "$script:PowerSchoolBaseUrl/ws/v1/district/student"
                        $queryParams = @("pagesize=$PageSize", "page=$pageNumber")
                        
                        if ($Expansions.Count -gt 0) {
                            $queryParams += "expansions=$($Expansions -join ',')"
                        }
                        
                        $endpoint += "?" + ($queryParams -join '&')
                        
                        Write-Verbose "Fetching page $pageNumber"
                        $response = Invoke-PowerSchoolApiRequest -Uri $endpoint -Headers $headers -Method Get
                        
                        if ($response.students -and $response.students.student) {
                            $pageStudents = $response.students.student
                            
                            # Handle single student response (not an array)
                            if ($pageStudents -isnot [array]) {
                                $pageStudents = @($pageStudents)
                            }
                            
                            $students += $pageStudents
                            Write-Verbose "Retrieved $($pageStudents.Count) students on page $pageNumber"
                            
                            # Check if there are more pages
                            if ($pageStudents.Count -lt $PageSize) {
                                $hasMore = $false
                            } else {
                                $pageNumber++
                            }
                        } else {
                            $hasMore = $false
                        }
                    }
                    
                    Write-Verbose "Retrieved total of $($students.Count) students"
                }
            }
            
            return $students
        }
        catch {
            Write-Error "Failed to retrieve PowerSchool student data: $_"
            throw
        }
    }

    end {
        Write-Verbose "PowerSchool student retrieval completed"
    }
}
