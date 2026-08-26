#Requires -Version 7.0

<#
.SYNOPSIS
    Invokes column mappings from a CSV row to a PowerSchool entity object.

.DESCRIPTION
    This private helper function takes a CSV row, an entity object, and column mappings,
    then applies the mappings to populate the entity object with proper data type conversions.

.PARAMETER CsvRow
    A hashtable or PSCustomObject representing one row from the CSV file.

.PARAMETER Entity
    The PowerSchool entity object to populate (PSStudent, PSContact, etc.)

.PARAMETER ColumnMappings
    Array of column mapping hashtables, each containing CSVColumn, EntityProperty, and DataType.

.PARAMETER DateTimeFormat
    Optional datetime format string to use for parsing datetime fields. If not provided,
    uses system default parsing. Common formats: 'MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd'.

.EXAMPLE
    $student = [PSStudent]::new()
    Invoke-ColumnMapping -CsvRow $row -Entity $student -ColumnMappings $mappings

.EXAMPLE
    $student = [PSStudent]::new()
    Invoke-ColumnMapping -CsvRow $row -Entity $student -ColumnMappings $mappings -DateTimeFormat 'dd/MM/yyyy'

.NOTES
    This is a private helper function used by CSV parsing functions and custom parsers.
#>
function Invoke-ColumnMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CsvRow,

        [Parameter(Mandatory = $true)]
        [object]$Entity,

        [Parameter(Mandatory = $true)]
        [array]$ColumnMappings,

        [Parameter(Mandatory = $false)]
        [string]$DateTimeFormat,

        [Parameter(Mandatory = $false)]
        [hashtable]$MappingContext = @{}
    )

    foreach ($mapping in $ColumnMappings) {
        $csvColumn = $mapping.CSVColumn
        $entityProperty = if ($mapping.EntityProperty) { $mapping.EntityProperty } else { "CustomFields.$($mapping.CustomField)" }
        $dataType = $mapping.DataType
        
        # Resolve direct, constant, or transformed values from the template mapping
        $value = Resolve-ColumnMappingValue -CsvRow $CsvRow -Mapping $mapping -MappingContext $MappingContext
        
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
                    # Check for column-specific DateTimeFormat first, then fall back to template-level format
                    $columnDateTimeFormat = $mapping.DateTimeFormat
                    if ($columnDateTimeFormat) {
                        [datetime]::ParseExact($value, $columnDateTimeFormat, $null)
                    }
                    elseif ($DateTimeFormat) {
                        [datetime]::ParseExact($value, $DateTimeFormat, $null)
                    }
                    else {
                        [datetime]::Parse($value)
                    }
                }
                catch {
                    $columnDateTimeFormat = $mapping.DateTimeFormat
                    if ($columnDateTimeFormat) {
                        Write-Warning "Failed to convert '$value' to datetime using column format '$columnDateTimeFormat' for property $entityProperty"
                    }
                    elseif ($DateTimeFormat) {
                        Write-Warning "Failed to convert '$value' to datetime using format '$DateTimeFormat' for property $entityProperty"
                    }
                    else {
                        Write-Warning "Failed to convert '$value' to datetime for property $entityProperty"
                    }
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
            if ($mapping.CustomField) {
                if (-not $Entity.PSObject.Properties['CustomFields']) {
                    throw "Entity type '$($Entity.GetType().Name)' does not support custom fields."
                }
                $Entity.CustomFields[$mapping.CustomField] = $convertedValue
            }
            else {
                $Entity.$entityProperty = $convertedValue
            }
        }
    }
}
