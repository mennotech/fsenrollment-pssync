#Requires -Version 7.0

<#
.SYNOPSIS
    Compares CSV student data with PowerSchool student data to detect changes.

.DESCRIPTION
    Analyzes student data from CSV (normalized PSNormalizedData) against student data
    from PowerSchool API to identify new students and updated students.
    Returns a structured change report.
    
    Only checks name fields (FirstName, MiddleName, LastName) for changes.
    
    Note: This function does NOT detect removed students (students in PowerSchool but not in CSV).
    It only identifies new students and updates to existing students.

.PARAMETER CsvData
    PSNormalizedData object containing students from CSV import.

.PARAMETER PowerSchoolData
    Array of student objects from PowerSchool API (from Get-PowerSchoolStudent -All).

.PARAMETER MatchOn
    Property to use for matching students between CSV and PowerSchool. Default is 'StudentNumber'.
    Currently only 'StudentNumber' is supported (matches against 'local_id' in PowerSchool API).

.OUTPUTS
    PSCustomObject with properties: New, Updated, Unchanged, Summary
    
    Note: The Removed collection is not included as this function does not detect removed students.

.EXAMPLE
    $csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    $psData = Get-PowerSchoolStudent -All
    $changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psData
    
    Write-Host "New: $($changes.New.Count), Updated: $($changes.Updated.Count)"
    
    Compares students using StudentNumber (default matching field).

.NOTES
    This function performs field-by-field comparison to detect what changed.
    The Updated collection contains objects with OldValue and NewValue properties.
    StudentNumber from CSV matches against 'local_id' in PowerSchool API response.
#>
function Compare-PSStudent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSNormalizedData]$CsvData,

        [Parameter(Mandatory = $true)]
        [array]$PowerSchoolData,

        [Parameter(Mandatory = $false)]
        [ValidateSet('StudentNumber')]
        [string]$MatchOn = 'StudentNumber'
    )

    begin {
        Write-Verbose "Starting student comparison"
        
        # Get template metadata for intelligent matching
        $keyField = 'StudentNumber'  # Default
        $psKeyField = 'local_id'  # Default
        $psKeyDataType = 'int'  # Default
        $checkForChanges = @('FirstName', 'MiddleName', 'LastName')  # Default
        
        if ($CsvData.TemplateMetadata) {
            if ($CsvData.TemplateMetadata.KeyField) {
                $keyField = $CsvData.TemplateMetadata.KeyField
                Write-Verbose "Using template key field: $keyField"
            }
            if ($CsvData.TemplateMetadata.PowerSchoolKeyField) {
                $psKeyField = $CsvData.TemplateMetadata.PowerSchoolKeyField
                Write-Verbose "Using PowerSchool key field: $psKeyField"
            }
            if ($CsvData.TemplateMetadata.PowerSchoolKeyDataType) {
                $psKeyDataType = $CsvData.TemplateMetadata.PowerSchoolKeyDataType
                Write-Verbose "Using PowerSchool key data type: $psKeyDataType"
            }
            if ($CsvData.TemplateMetadata.CheckForChanges) {
                $checkForChanges = $CsvData.TemplateMetadata.CheckForChanges
                Write-Verbose "Fields to check for changes: $($checkForChanges -join ', ')"
            }
        }
        
        # Initialize result collections
        # Note: We do not track removed students (in PowerSchool but not in CSV)
        $newStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        $updatedStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        $unchangedStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Create lookup dictionaries for efficient comparison
        # Use template metadata to determine proper type conversion
        $psLookup = @{}
        foreach ($psStudent in $PowerSchoolData) {
            # Get the PowerSchool key value
            $psKeyValue = $psStudent.$psKeyField
            
            # Convert key to string for consistent dictionary lookup
            # This handles type mismatches between CSV (string) and PowerSchool API (various types)
            if ($null -ne $psKeyValue) {
                $key = $psKeyValue.ToString()
                
                if (-not [string]::IsNullOrWhiteSpace($key)) {
                    $psLookup[$key] = $psStudent
                }
            }
        }
        
        Write-Verbose "PowerSchool has $($psLookup.Count) students indexed by $psKeyField"
        Write-Verbose "CSV has $($CsvData.Students.Count) students"
    }

    process {
        try {
            # Track which PowerSchool students were matched
            $matchedPsStudents = @{}
            
            # Compare each CSV student with PowerSchool
            foreach ($csvStudent in $CsvData.Students) {
                # Get the match key value from CSV student using template metadata
                $matchKey = $csvStudent.$keyField
                
                if ([string]::IsNullOrWhiteSpace($matchKey)) {
                    Write-Warning "CSV student missing $keyField match field, skipping"
                    continue
                }
                
                if ($psLookup.ContainsKey($matchKey)) {
                    # Student exists in PowerSchool - check for changes
                    $psStudent = $psLookup[$matchKey]
                    $matchedPsStudents[$matchKey] = $true
                    
                    # Pass checkForChanges array and column mappings to Compare-StudentFields
                    $changes = Compare-StudentFields -CsvStudent $csvStudent -PowerSchoolStudent $psStudent -CheckForChanges $checkForChanges -ColumnMappings $CsvData.TemplateMetadata.ColumnMappings
                    
                    if ($changes.Count -gt 0) {
                        # Student has changes
                        $updatedStudents.Add([PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = $keyField
                            CsvStudent = $csvStudent
                            PowerSchoolStudent = $psStudent
                            Changes = $changes
                        })
                        Write-Verbose "Student $matchKey has $($changes.Count) field changes"
                    } else {
                        # Student unchanged
                        $unchangedStudents.Add([PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = $keyField
                            Student = $csvStudent
                        })
                    }
                } else {
                    # Student is new (not in PowerSchool)
                    $newStudents.Add([PSCustomObject]@{
                        MatchKey = $matchKey
                        MatchField = $keyField
                        Student = $csvStudent
                    })
                    Write-Verbose "Student $matchKey is new (not in PowerSchool)"
                }
            }
            
            # Create summary (excluding removed students)
            $summary = [PSCustomObject]@{
                TotalInCsv = $CsvData.Students.Count
                TotalInPowerSchool = $PowerSchoolData.Count
                NewCount = $newStudents.Count
                UpdatedCount = $updatedStudents.Count
                UnchangedCount = $unchangedStudents.Count
                MatchField = $keyField
            }
            
            # Create result object (no Removed collection)
            $result = [PSCustomObject]@{
                New = $newStudents
                Updated = $updatedStudents
                Unchanged = $unchangedStudents
                Summary = $summary
            }
            
            Write-Verbose "Comparison complete: $($newStudents.Count) new, $($updatedStudents.Count) updated, $($unchangedStudents.Count) unchanged"
            
            return $result
        }
        catch {
            Write-Error "Failed to compare student data: $_"
            throw
        }
    }

    end {
        Write-Verbose "Student comparison completed"
    }
}
