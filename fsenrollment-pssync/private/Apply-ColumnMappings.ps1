#Requires -Version 7.0

<#
.SYNOPSIS
    Applies column mappings from a CSV row to a PowerSchool entity object.

.DESCRIPTION
    This private helper function takes a CSV row, an entity object, and column mappings,
    then applies the mappings to populate the entity object with proper data type conversions.

.PARAMETER CsvRow
    A hashtable or PSCustomObject representing one row from the CSV file.

.PARAMETER Entity
    The PowerSchool entity object to populate (PSStudent, PSContact, etc.)

.PARAMETER ColumnMappings
    Array of column mapping hashtables, each containing CSVColumn, EntityProperty, and DataType.

.EXAMPLE
    $student = [PSStudent]::new()
    Apply-ColumnMappings -CsvRow $row -Entity $student -ColumnMappings $mappings

.NOTES
    This is a private helper function used by CSV parsing functions and custom parsers.
#>
function Apply-ColumnMappings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CsvRow,

        [Parameter(Mandatory = $true)]
        [object]$Entity,

        [Parameter(Mandatory = $true)]
        [array]$ColumnMappings
    )

    foreach ($mapping in $ColumnMappings) {
        $csvColumn = $mapping.CSVColumn
        $entityProperty = $mapping.EntityProperty
        $dataType = $mapping.DataType
        
        # Get the value from CSV row
        $value = $CsvRow.$csvColumn
        
        # Skip if value is null or empty string
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }
        
        # Convert to appropriate data type
        $convertedValue = switch ($dataType) {
            'int' {
                try {
                    [int]$value
                }
                catch {
                    Write-Warning "Failed to convert '$value' to int for property $entityProperty"
                    0
                }
            }
            'bool' {
                if ($value -eq '1' -or $value -eq 'true' -or $value -eq 'True') {
                    $true
                }
                elseif ($value -eq '0' -or $value -eq 'false' -or $value -eq 'False') {
                    $false
                }
                else {
                    Write-Warning "Unexpected boolean value '$value' for property $entityProperty. Expected '0', '1', 'true', or 'false'. Attempting standard conversion."
                    [bool]$value
                }
            }
            'datetime' {
                try {
                    [datetime]::Parse($value)
                }
                catch {
                    Write-Warning "Failed to convert '$value' to datetime for property $entityProperty"
                    $null
                }
            }
            default {
                # Default to string
                [string]$value
            }
        }
        
        # Set the property value
        if ($null -ne $convertedValue -or $dataType -eq 'bool') {
            $Entity.$entityProperty = $convertedValue
        }
    }
}
