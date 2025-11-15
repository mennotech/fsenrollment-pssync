#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare fields between CSV and PowerSchool person records.

.DESCRIPTION
    Performs field-by-field comparison between a CSV contact (PSContact) and a PowerSchool
    PowerQuery person object. Returns a list of fields that have changed with old and new values.
    
    Maps PSContact properties to PowerQuery person fields:
    - FirstName → person_firstname
    - MiddleName → person_middlename
    - LastName → person_lastname
    - Gender → person_gender_code
    - Employer → person_employer

.PARAMETER CsvContact
    PSContact object from CSV data.

.PARAMETER PowerSchoolPerson
    Person object from PowerSchool PowerQuery (com.fsenrollment.dats.person).

.PARAMETER CheckForChanges
    Array of field names to check for changes. Only these fields will be compared.

.OUTPUTS
    Array of PSCustomObjects with properties: Field, PowerSchoolField, OldValue, NewValue
    
    Only includes changes to fields specified in CheckForChanges array.

.NOTES
    This is a private function used internally by Compare-PSContact.
    Maps PSContact properties to PowerSchool PowerQuery person field names.
#>
function Compare-ContactFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSContact]$CsvContact,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PowerSchoolPerson,

        [Parameter(Mandatory = $false)]
        [string[]]$CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'Gender', 'Employer')
    )

    $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Mapping of PSContact properties to PowerQuery person fields
    $fieldMapping = @{
        'FirstName' = 'person_firstname'
        'MiddleName' = 'person_middlename'
        'LastName' = 'person_lastname'
        'Gender' = 'person_gender_code'
        'Employer' = 'person_employer'
    }

    # Only compare fields specified in CheckForChanges array
    foreach ($fieldName in $CheckForChanges) {
        # Get the CSV value
        $csvValue = $CsvContact.$fieldName
        
        # Get the corresponding PowerSchool field name
        $psFieldName = $fieldMapping[$fieldName]
        
        if (-not $psFieldName) {
            Write-Warning "No PowerSchool field mapping found for $fieldName"
            continue
        }
        
        # Get the PowerSchool value
        $psValue = $PowerSchoolPerson.$psFieldName

        # Normalize values for comparison
        $csvValueNormalized = Normalize-ComparisonValue -Value $csvValue
        $psValueNormalized = Normalize-ComparisonValue -Value $psValue

        # Compare normalized values
        if ($csvValueNormalized -ne $psValueNormalized) {
            $changes.Add([PSCustomObject]@{
                Field = $fieldName
                PowerSchoolField = $psFieldName
                OldValue = $psValueNormalized
                NewValue = $csvValueNormalized
            })
        }
    }

    return $changes
}
