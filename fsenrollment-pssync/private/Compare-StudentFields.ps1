#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare fields between CSV and PowerSchool student records.

.DESCRIPTION
    Performs field-by-field comparison between a CSV student (PSStudent) and a PowerSchool
    API student object. Returns a list of fields that have changed with old and new values.
    
    Uses template metadata to determine which fields to check and how to map them to
    PowerSchool API fields.

.PARAMETER CsvStudent
    PSStudent object from CSV data.

.PARAMETER PowerSchoolStudent
    Student object from PowerSchool API.

.PARAMETER CheckForChanges
    Array of field names to check for changes. Only these fields will be compared.

.PARAMETER ColumnMappings
    Array of column mapping objects from the template containing PowerSchool field mappings.

.OUTPUTS
    Array of PSCustomObjects with properties: Field, OldValue, NewValue
    
    Only includes changes to fields specified in CheckForChanges array.

.NOTES
    This is a private function used internally by Compare-PSStudent.
    Maps PSStudent properties to PowerSchool API field names using template metadata.
    Name fields are accessed from the nested 'name' object in PowerSchool API response.
#>
function Compare-StudentFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSStudent]$CsvStudent,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PowerSchoolStudent,

        [Parameter(Mandatory = $false)]
        [string[]]$CheckForChanges = @('FirstName', 'MiddleName', 'LastName'),

        [Parameter(Mandatory = $false)]
        [array]$ColumnMappings = @()
    )

    $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Only compare fields specified in CheckForChanges array
    # Use column mappings to determine PowerSchool field paths
    foreach ($fieldName in $CheckForChanges) {
        $csvValue = $CsvStudent.$fieldName
        
        # Find the PowerSchool field mapping for this field
        $mapping = $ColumnMappings | Where-Object { $_.EntityProperty -eq $fieldName } | Select-Object -First 1
        
        if ($mapping -and $mapping.PowerSchoolAPIField) {
            $psFieldPath = $mapping.PowerSchoolAPIField
            
            # Handle different field path formats
            if ($psFieldPath -match '^extension\.([^.]+)\.(.+)$') {
                # Extension field: extension.table_name.field_name
                $extensionTable = $matches[1]
                $extensionField = $matches[2]
                
                # Access nested extension data structure
                $psValue = $null
                if ($PowerSchoolStudent._extension_data -and $PowerSchoolStudent._extension_data._table_extension) {
                    $tableExt = $PowerSchoolStudent._extension_data._table_extension | Where-Object { $_.name -eq $extensionTable } | Select-Object -First 1
                    if ($tableExt -and $tableExt._field) {
                        $field = $tableExt._field | Where-Object { $_.name -eq $extensionField } | Select-Object -First 1
                        if ($field) {
                            $psValue = $field.value
                        }
                    }
                }
            }
            elseif ($psFieldPath -match '^@([^.]+)\.(.+)$') {
                # Expansion field: @expansion_name.field_name
                $expansionName = $matches[1]
                $expansionField = $matches[2]
                
                # Access expansion data
                $psValue = $null
                if ($PowerSchoolStudent.$expansionName) {
                    $psValue = $PowerSchoolStudent.$expansionName.$expansionField
                }
            }
            else {
                # Standard or nested field: 'field' or 'object.field'
                $psValue = $PowerSchoolStudent
                $fieldParts = $psFieldPath -split '\.'
                foreach ($part in $fieldParts) {
                    if ($null -ne $psValue) {
                        $psValue = $psValue.$part
                    } else {
                        break
                    }
                }
            }
        } else {
            # Fallback: Try direct field access or nested name object
            # This maintains backward compatibility
            if ($PowerSchoolStudent.name -and $PowerSchoolStudent.name.PSObject.Properties[$fieldName.ToLower() -replace 'name$', '_name']) {
                $psFieldName = $fieldName.ToLower() -replace 'firstname', 'first_name' -replace 'middlename', 'middle_name' -replace 'lastname', 'last_name'
                $psValue = $PowerSchoolStudent.name.$psFieldName
                $psFieldPath = "name.$psFieldName"
            } else {
                $psValue = $null
                $psFieldPath = $fieldName
            }
        }

        # Normalize values for comparison
        $csvValueNormalized = Normalize-ComparisonValue -Value $csvValue
        $psValueNormalized = Normalize-ComparisonValue -Value $psValue

        # Compare normalized values
        if ($csvValueNormalized -ne $psValueNormalized) {
            $changes.Add([PSCustomObject]@{
                Field = $fieldName
                PowerSchoolAPIField = $psFieldPath
                OldValue = $psValueNormalized
                NewValue = $csvValueNormalized
            })
        }
    }

    return $changes
}
