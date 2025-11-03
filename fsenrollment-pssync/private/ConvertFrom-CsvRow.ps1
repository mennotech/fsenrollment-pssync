#Requires -Version 7.0

<#
.SYNOPSIS
    Converts CSV data to PowerSchool entity objects based on a template mapping.

.DESCRIPTION
    This private helper function takes CSV row data and a template mapping configuration,
    then creates PowerSchool entity objects with proper data type conversions.
    
    Uses the Invoke-ColumnMapping helper function to apply the column mappings.

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

        # Apply column mappings to the entity
        Invoke-ColumnMapping -CsvRow $CsvRow -Entity $entity -ColumnMappings $TemplateConfig.ColumnMappings

        return $entity
    }
    catch {
        Write-Error "Failed to convert CSV row to $($TemplateConfig.EntityType): $_"
        throw
    }
}
