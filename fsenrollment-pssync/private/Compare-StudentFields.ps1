#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare fields between CSV and PowerSchool student records.

.DESCRIPTION
    Performs field-by-field comparison between a CSV student (PSStudent) and a PowerSchool
    API student object. Returns a list of fields that have changed with old and new values.
    
    Currently only compares name fields: FirstName, MiddleName, and LastName.

.PARAMETER CsvStudent
    PSStudent object from CSV data.

.PARAMETER PowerSchoolStudent
    Student object from PowerSchool API.

.OUTPUTS
    Array of PSCustomObjects with properties: Field, OldValue, NewValue
    
    Only includes changes to name fields (FirstName, MiddleName, LastName).

.NOTES
    This is a private function used internally by Compare-PSStudent.
    Maps PSStudent properties to PowerSchool API field names.
    Name fields are accessed from the nested 'name' object in PowerSchool API response.
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

    # Only compare name fields as requested
    # Handle name fields separately as they are nested in PowerSchool API
    $nameFieldMappings = @{
        'FirstName' = 'first_name'
        'MiddleName' = 'middle_name'
        'LastName' = 'last_name'
    }

    # Compare name fields (nested in PowerSchool response)
    foreach ($csvField in $nameFieldMappings.Keys) {
        $psField = $nameFieldMappings[$csvField]
        $csvValue = $CsvStudent.$csvField
        
        # Access nested name object in PowerSchool student
        $psValue = if ($PowerSchoolStudent.name) {
            $PowerSchoolStudent.name.$psField
        } else {
            $null
        }

        # Normalize values for comparison
        $csvValueNormalized = Normalize-ComparisonValue -Value $csvValue
        $psValueNormalized = Normalize-ComparisonValue -Value $psValue

        # Compare normalized values
        if ($csvValueNormalized -ne $psValueNormalized) {
            $changes.Add([PSCustomObject]@{
                Field = $csvField
                PowerSchoolField = "name.$psField"
                OldValue = $psValueNormalized
                NewValue = $csvValueNormalized
            })
        }
    }

    return $changes
}
