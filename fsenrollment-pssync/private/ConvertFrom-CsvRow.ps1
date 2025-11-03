#Requires -Version 7.0

<#
.SYNOPSIS
    Converts CSV data to PowerSchool entity objects based on a template mapping.

.DESCRIPTION
    This private helper function takes CSV row data and a template mapping configuration,
    then creates PowerSchool entity objects with proper data type conversions.

.PARAMETER CsvRow
    A hashtable or PSCustomObject representing one row from the CSV file.

.PARAMETER TemplateConfig
    The template configuration hashtable containing column mappings and entity type.

.OUTPUTS
    Object representing the PowerSchool entity (PSStudent, PSContact, etc.)

.EXAMPLE
    $student = ConvertFrom-CsvRow -CsvRow $row -TemplateConfig $template

.NOTES
    This is a private helper function used by the CSV parsing functions.
#>
function ConvertFrom-CsvRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CsvRow,

        [Parameter(Mandatory = $true)]
        [hashtable]$TemplateConfig
    )

    try {
        # Create the entity object based on the EntityType
        $entityTypeName = $TemplateConfig.EntityType
        $entity = New-Object -TypeName $entityTypeName

        # Process each column mapping
        foreach ($mapping in $TemplateConfig.ColumnMappings) {
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
                        $null
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
            if ($null -ne $convertedValue) {
                $entity.$entityProperty = $convertedValue
            }
        }

        return $entity
    }
    catch {
        Write-Error "Failed to convert CSV row to $($TemplateConfig.EntityType): $_"
        throw
    }
}
