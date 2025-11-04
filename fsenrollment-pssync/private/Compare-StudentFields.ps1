#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare fields between CSV and PowerSchool student records.

.DESCRIPTION
    Performs field-by-field comparison between a CSV student (PSStudent) and a PowerSchool
    API student object. Returns a list of fields that have changed with old and new values.

.PARAMETER CsvStudent
    PSStudent object from CSV data.

.PARAMETER PowerSchoolStudent
    Student object from PowerSchool API.

.OUTPUTS
    Array of PSCustomObjects with properties: Field, OldValue, NewValue

.NOTES
    This is a private function used internally by Compare-PSStudent.
    Maps PSStudent properties to PowerSchool API field names.
#>
function Compare-StudentFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSStudent]$CsvStudent,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PowerSchoolStudent
    )

    $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Define field mappings: PSStudent property -> PowerSchool API field
    $fieldMappings = @{
        'FirstName' = 'first_name'
        'MiddleName' = 'middle_name'
        'LastName' = 'last_name'
        'GradeLevel' = 'grade_level'
        'Gender' = 'gender'
        'DOB' = 'dob'
        'FTEID' = 'fteid'
        'EnrollStatus' = 'enroll_status'
        'HomePhone' = 'home_phone'
        'Street' = 'street'
        'City' = 'city'
        'State' = 'state'
        'Zip' = 'zip'
        'MailingStreet' = 'mailing_street'
        'MailingCity' = 'mailing_city'
        'MailingState' = 'mailing_state'
        'MailingZip' = 'mailing_zip'
        'SchoolID' = 'schoolid'
    }

    foreach ($csvField in $fieldMappings.Keys) {
        $psField = $fieldMappings[$csvField]
        $csvValue = $CsvStudent.$csvField
        $psValue = $PowerSchoolStudent.$psField

        # Normalize values for comparison
        $csvValueNormalized = Normalize-ComparisonValue -Value $csvValue
        $psValueNormalized = Normalize-ComparisonValue -Value $psValue

        # Compare normalized values
        if ($csvValueNormalized -ne $psValueNormalized) {
            $changes.Add([PSCustomObject]@{
                Field = $csvField
                PowerSchoolField = $psField
                OldValue = $psValueNormalized
                NewValue = $csvValueNormalized
            })
        }
    }

    # Check date fields separately (need special handling)
    $dateFields = @{
        'EntryDate' = 'entrydate'
        'ExitDate' = 'exitdate'
    }

    foreach ($csvField in $dateFields.Keys) {
        $psField = $dateFields[$csvField]
        $csvValue = $CsvStudent.$csvField
        $psValue = $PowerSchoolStudent.$psField

        # Compare dates (only date part, ignore time)
        $csvDate = if ($csvValue -and $csvValue -is [datetime]) { $csvValue.Date } else { $null }
        $psDate = if ($psValue) {
            try {
                ([datetime]$psValue).Date
            } catch {
                $null
            }
        } else {
            $null
        }

        if (($null -eq $csvDate -and $null -ne $psDate) -or
            ($null -ne $csvDate -and $null -eq $psDate) -or
            ($null -ne $csvDate -and $null -ne $psDate -and $csvDate -ne $psDate)) {
            
            $changes.Add([PSCustomObject]@{
                Field = $csvField
                PowerSchoolField = $psField
                OldValue = if ($psDate) { $psDate.ToString('yyyy-MM-dd') } else { $null }
                NewValue = if ($csvDate) { $csvDate.ToString('yyyy-MM-dd') } else { $null }
            })
        }
    }

    return $changes
}
