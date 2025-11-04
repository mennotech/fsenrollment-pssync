#Requires -Version 7.0

<#
.SYNOPSIS
    Compares CSV student data with PowerSchool student data to detect changes.

.DESCRIPTION
    Analyzes student data from CSV (normalized PSNormalizedData) against student data
    from PowerSchool API to identify new students, updated students, and students that
    may have been removed. Returns a structured change report.

.PARAMETER CsvData
    PSNormalizedData object containing students from CSV import.

.PARAMETER PowerSchoolData
    Array of student objects from PowerSchool API (from Get-PowerSchoolStudent -All).

.PARAMETER MatchOn
    Property to use for matching students between CSV and PowerSchool. Default is 'StudentNumber'.
    Can be 'StudentNumber' or 'FTEID'.

.OUTPUTS
    PSCustomObject with properties: New, Updated, Unchanged, Removed, Summary

.EXAMPLE
    $csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    $psData = Get-PowerSchoolStudent -All
    $changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psData
    
    Write-Host "New: $($changes.New.Count), Updated: $($changes.Updated.Count)"

.EXAMPLE
    $changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psData -MatchOn 'FTEID'
    
    Matches students using FTEID instead of StudentNumber.

.NOTES
    This function performs field-by-field comparison to detect what changed.
    The Updated collection contains objects with OldValue and NewValue properties.
#>
function Compare-PSStudent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSNormalizedData]$CsvData,

        [Parameter(Mandatory = $true)]
        [array]$PowerSchoolData,

        [Parameter(Mandatory = $false)]
        [ValidateSet('StudentNumber', 'FTEID')]
        [string]$MatchOn = 'StudentNumber'
    )

    begin {
        Write-Verbose "Starting student comparison using match field: $MatchOn"
        
        # Initialize result collections
        $newStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        $updatedStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        $unchangedStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        $removedStudents = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Create lookup dictionaries for efficient comparison
        $psLookup = @{}
        foreach ($psStudent in $PowerSchoolData) {
            $key = switch ($MatchOn) {
                'StudentNumber' { $psStudent.student_number }
                'FTEID' { $psStudent.fteid }
            }
            
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $psLookup[$key] = $psStudent
            }
        }
        
        Write-Verbose "PowerSchool has $($psLookup.Count) students indexed by $MatchOn"
        Write-Verbose "CSV has $($CsvData.Students.Count) students"
    }

    process {
        try {
            # Track which PowerSchool students were matched
            $matchedPsStudents = @{}
            
            # Compare each CSV student with PowerSchool
            foreach ($csvStudent in $CsvData.Students) {
                $matchKey = switch ($MatchOn) {
                    'StudentNumber' { $csvStudent.StudentNumber }
                    'FTEID' { $csvStudent.FTEID }
                }
                
                if ([string]::IsNullOrWhiteSpace($matchKey)) {
                    Write-Warning "CSV student missing $MatchOn match field, skipping"
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
                            MatchField = $MatchOn
                            CsvStudent = $csvStudent
                            PowerSchoolStudent = $psStudent
                            Changes = $changes
                        })
                        Write-Verbose "Student $matchKey has $($changes.Count) field changes"
                    } else {
                        # Student unchanged
                        $unchangedStudents.Add([PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = $MatchOn
                            Student = $csvStudent
                        })
                    }
                } else {
                    # Student is new (not in PowerSchool)
                    $newStudents.Add([PSCustomObject]@{
                        MatchKey = $matchKey
                        MatchField = $MatchOn
                        Student = $csvStudent
                    })
                    Write-Verbose "Student $matchKey is new (not in PowerSchool)"
                }
            }
            
            # Find students in PowerSchool but not in CSV (potentially removed)
            foreach ($key in $psLookup.Keys) {
                if (-not $matchedPsStudents.ContainsKey($key)) {
                    $removedStudents.Add([PSCustomObject]@{
                        MatchKey = $key
                        MatchField = $MatchOn
                        Student = $psLookup[$key]
                    })
                    Write-Verbose "Student $key in PowerSchool but not in CSV (potentially removed)"
                }
            }
            
            # Create summary
            $summary = [PSCustomObject]@{
                TotalInCsv = $CsvData.Students.Count
                TotalInPowerSchool = $PowerSchoolData.Count
                NewCount = $newStudents.Count
                UpdatedCount = $updatedStudents.Count
                UnchangedCount = $unchangedStudents.Count
                RemovedCount = $removedStudents.Count
                MatchField = $MatchOn
            }
            
            # Create result object
            $result = [PSCustomObject]@{
                New = $newStudents
                Updated = $updatedStudents
                Unchanged = $unchangedStudents
                Removed = $removedStudents
                Summary = $summary
            }
            
            Write-Verbose "Comparison complete: $($newStudents.Count) new, $($updatedStudents.Count) updated, $($unchangedStudents.Count) unchanged, $($removedStudents.Count) removed"
            
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
