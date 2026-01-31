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
    If TemplateMetadata or TemplateName is provided, required expansions are automatically detected and merged.

.PARAMETER Extensions
    Array of extensions to include in the response for custom PowerSchool extensions.
    If TemplateMetadata or TemplateName is provided, required extensions are automatically detected and merged.

.PARAMETER TemplateMetadata
    Template metadata hashtable from Import-FSCsv. When provided, automatically detects required
    expansions and extensions from PowerSchoolAPIField mappings in the template.

.PARAMETER TemplateName
    Name of the template configuration file (without .psd1 extension). When provided, loads the
    template and automatically detects required expansions and extensions.

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
    $csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    $students = Get-PowerSchoolStudent -All -TemplateMetadata $csvData.TemplateMetadata
    
    Automatically detects and includes required expansions and extensions based on template configuration.

.EXAMPLE
    $students = Get-PowerSchoolStudent -All -TemplateName 'fs_powerschool_nonapi_report_students'
    
    Loads template and automatically includes required expansions and extensions.

.EXAMPLE
    $student = Get-PowerSchoolStudent -DCID 12345 -Expansions @('demographics', 'addresses')
    
    Retrieves a student by PowerSchool internal DCID with demographics and addresses expanded.
    Note: DCID is not typically available from CSV imports.

.EXAMPLE
    $students = Get-PowerSchoolStudent -All -Extensions @('u_students_extension')
    
    Retrieves all students with a custom PowerSchool extension included.

.NOTES
    Requires an active PowerSchool connection via Connect-PowerSchool.
    Implements exponential backoff retry logic for API failures.
    Supports both expansions (standard fields) and extensions (custom fields).
    When using TemplateMetadata or TemplateName, required fields are automatically detected.
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
        [string[]]$Expansions = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$Extensions = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateMetadata,

        [Parameter(Mandatory = $false)]
        [string]$TemplateName
    )

    begin {
        Write-Verbose "Getting PowerSchool student data"
        
        # Ensure we have a valid connection
        Test-PowerSchoolConnection
        
        # Auto-detect required expansions and extensions from template
        if ($TemplateName) {
            Write-Verbose "Loading template: $TemplateName"
            $templatePath = Join-Path $PSScriptRoot "../../config/templates/$TemplateName.psd1"
            if (-not (Test-Path $templatePath)) {
                throw "Template not found: $templatePath"
            }
            $TemplateMetadata = Import-PowerShellDataFile -Path $templatePath
        }
        
        if ($TemplateMetadata) {
            Write-Verbose "Auto-detecting required PowerSchool fields from template"
            $required = Get-RequiredPowerSchoolFields -TemplateMetadata $TemplateMetadata
            
            # Merge auto-detected with manually specified (avoid duplicates)
            $allExpansions = [System.Collections.Generic.HashSet[string]]::new([string[]]$Expansions)
            $allExtensions = [System.Collections.Generic.HashSet[string]]::new([string[]]$Extensions)
            
            foreach ($exp in $required.Expansions) {
                [void]$allExpansions.Add($exp)
            }
            foreach ($ext in $required.Extensions) {
                [void]$allExtensions.Add($ext)
            }
            
            $Expansions = @($allExpansions)
            $Extensions = @($allExtensions)
            
            if ($Expansions.Count -gt 0) {
                Write-Verbose "Using expansions: $($Expansions -join ', ')"
            }
            if ($Extensions.Count -gt 0) {
                Write-Verbose "Using extensions: $($Extensions -join ', ')"
            }
        }
        
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
                    
                    # Build query parameters
                    $queryParams = @()
                    
                    # Add expansions if provided
                    if ($Expansions.Count -gt 0) {
                        $queryParams += "expansions=$($Expansions -join ',')"
                    }
                    
                    # Add extensions if provided
                    if ($Extensions.Count -gt 0) {
                        $queryParams += "extensions=$($Extensions -join ',')"
                    }
                    
                    if ($queryParams.Count -gt 0) {
                        $endpoint += "?" + ($queryParams -join '&')
                    }
                    
                    $response = Invoke-PowerSchoolApiRequest -Uri $endpoint -Headers $headers -Method Get
                    $students += $response.student
                }
                
                'ByNumber' {
                    Write-Verbose "Fetching student with number: $StudentNumber"
                    
                    # First, get all students and filter (PowerSchool API doesn't have direct student number lookup)
                    # Alternatively, we could use the query endpoint
                    $endpoint = "$script:PowerSchoolBaseUrl/ws/v1/district/student"
                    $queryParams = @("q=local_id==$StudentNumber")
                    
                    if ($Expansions.Count -gt 0) {
                        $queryParams += "expansions=$($Expansions -join ',')"
                    }
                    
                    if ($Extensions.Count -gt 0) {
                        $queryParams += "extensions=$($Extensions -join ',')"
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
                        
                        if ($Extensions.Count -gt 0) {
                            $queryParams += "extensions=$($Extensions -join ',')"
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
            
            return , $students
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
