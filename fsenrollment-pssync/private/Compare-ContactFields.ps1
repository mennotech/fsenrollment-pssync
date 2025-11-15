#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare fields between CSV and PowerSchool person records.

.DESCRIPTION
    Performs field-by-field comparison between a CSV contact (PSContact) and a PowerSchool
    PowerQuery person object. Returns a list of fields that have changed with old and new values.
    
    Uses ColumnMappings from template configuration to determine PowerQuery field names.
    If ColumnMappings are not provided, uses default field mappings.

.PARAMETER CsvContact
    PSContact object from CSV data.

.PARAMETER PowerSchoolPerson
    Person object from PowerSchool PowerQuery (com.fsenrollment.dats.person).

.PARAMETER CheckForChanges
    Array of field names to check for changes. Only these fields will be compared.

.PARAMETER ColumnMappings
    Array of column mapping objects from the template containing PowerSchoolAPIField mappings.

.OUTPUTS
    Array of PSCustomObjects with properties: Field, PowerSchoolField, OldValue, NewValue
    
    Only includes changes to fields specified in CheckForChanges array.

.NOTES
    This is a private function used internally by Compare-PSContact.
    Maps PSContact properties to PowerSchool PowerQuery person field names using template ColumnMappings.
#>
function Compare-ContactFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSContact]$CsvContact,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PowerSchoolPerson,

        [Parameter(Mandatory = $false)]
        [string[]]$CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'Gender', 'Employer'),

        [Parameter(Mandatory = $false)]
        [array]$ColumnMappings = @()
    )

    $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Default mapping of PSContact properties to PowerQuery person fields (fallback)
    $defaultFieldMapping = @{
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
        
        # Get the corresponding PowerSchool field name from ColumnMappings or default
        $psFieldName = $null
        
        if ($ColumnMappings -and $ColumnMappings.Count -gt 0) {
            # Find mapping from template
            $mapping = $ColumnMappings | Where-Object { $_.EntityProperty -eq $fieldName } | Select-Object -First 1
            if ($mapping -and $mapping.PowerSchoolAPIField) {
                $psFieldName = $mapping.PowerSchoolAPIField
            }
        }
        
        # Fallback to default mapping if not found in ColumnMappings
        if (-not $psFieldName) {
            $psFieldName = $defaultFieldMapping[$fieldName]
        }
        
        if (-not $psFieldName) {
            Write-Warning "No PowerSchool field mapping found for $fieldName"
            continue
        }
        
        # Get the PowerSchool value (PowerQuery fields are flat, not nested)
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
