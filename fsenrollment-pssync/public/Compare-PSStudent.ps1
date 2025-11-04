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
        Write-Verbose "Starting student comparison using match field: $MatchOn"
        
        # Initialize result collections
        # Note: We do not track removed students (in PowerSchool but not in CSV)
        $newStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        $updatedStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        $unchangedStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Create lookup dictionaries for efficient comparison
        # Note: PowerSchool API returns local_id as Integer, CSV has StudentNumber as String
        # Convert to string for consistent comparison
        $psLookup = @{}
        foreach ($psStudent in $PowerSchoolData) {
            # PowerSchool API returns student_number as 'local_id' (Integer)
            # Convert to string to match CSV StudentNumber type
            $key = $psStudent.local_id.ToString()
            
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $psLookup[$key] = $psStudent
            }
        }
        
        Write-Verbose "PowerSchool has $($psLookup.Count) students indexed by local_id (StudentNumber)"
        Write-Verbose "CSV has $($CsvData.Students.Count) students"
    }

    process {
        try {
            # Track which PowerSchool students were matched
            $matchedPsStudents = @{}
            
            # Compare each CSV student with PowerSchool
            foreach ($csvStudent in $CsvData.Students) {
                $matchKey = $csvStudent.StudentNumber
                
                if ([string]::IsNullOrWhiteSpace($matchKey)) {
                    Write-Warning "CSV student missing $MatchOn match field, skipping"
                    continue
                }
                if ([string]::IsNullOrWhiteSpace($matchKey)) {
                    Write-Warning "CSV student missing StudentNumber match field, skipping"
                    continue
                }
                
                if ($psLookup.ContainsKey($matchKey)) {
                    # Student exists in PowerSchool - check for changes
                    $psStudent = $psLookup[$matchKey]
                    $matchedPsStudents[$matchKey] = $true
                    
                    $changes = Compare-StudentFields -CsvStudent $csvStudent -PowerSchoolStudent $psStudent
                    
                    if ($changes.Count -gt 0) {
                        # Student has changes
                        $updatedStudents.Add([PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = 'StudentNumber'
                            CsvStudent = $csvStudent
                            PowerSchoolStudent = $psStudent
                            Changes = $changes
                        })
                        Write-Verbose "Student $matchKey has $($changes.Count) field changes"
                    } else {
                        # Student unchanged
                        $unchangedStudents.Add([PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = 'StudentNumber'
                            Student = $csvStudent
                        })
                    }
                } else {
                    # Student is new (not in PowerSchool)
                    $newStudents.Add([PSCustomObject]@{
                        MatchKey = $matchKey
                        MatchField = 'StudentNumber'
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
                MatchField = 'StudentNumber'
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
