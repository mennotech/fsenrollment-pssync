#Requires -Version 7.0

<#
.SYNOPSIS
    Extracts required PowerSchool extensions and expansions from template metadata.

.DESCRIPTION
    Analyzes template column mappings to determine which PowerSchool API extensions and
    expansions are required to retrieve all fields specified in the template.
    
    Parses PowerSchoolAPIField values:
    - extension.table_name.field → adds 'table_name' to extensions
    - @expansion_name.field → adds 'expansion_name' to expansions

.PARAMETER TemplateMetadata
    Template metadata hashtable containing ColumnMappings. Typically accessed from
    PSNormalizedData.TemplateMetadata after calling Import-FSCsv.

.OUTPUTS
    PSCustomObject with properties: Extensions (array), Expansions (array)

.EXAMPLE
    $csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    $required = Get-RequiredPowerSchoolFields -TemplateMetadata $csvData.TemplateMetadata
    $students = Get-PowerSchoolStudent -All -Extensions $required.Extensions -Expansions $required.Expansions
    
    Automatically detects and retrieves all PowerSchool data needed for comparison based on template.

.NOTES
    This function helps ensure all necessary PowerSchool data is retrieved for accurate comparison.
    Automatically detects required API features from template configuration.
    Returns empty arrays if no extensions or expansions are required.
#>
function Get-RequiredPowerSchoolFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateMetadata
    )

    $extensions = [System.Collections.Generic.HashSet[string]]::new()
    $expansions = [System.Collections.Generic.HashSet[string]]::new()

    if ($TemplateMetadata -and $TemplateMetadata.ColumnMappings) {
        foreach ($mapping in $TemplateMetadata.ColumnMappings) {
            if ($mapping.PowerSchoolAPIField) {
                $fieldPath = $mapping.PowerSchoolAPIField
                
                # Check for extension fields: extension.table_name.field_name
                if ($fieldPath -match '^extension\.([^.]+)\.') {
                    $extensionTable = $matches[1]
                    [void]$extensions.Add($extensionTable)
                    Write-Verbose "Found required extension: $extensionTable"
                }
                # Check for expansion fields: @expansion_name.field_name
                elseif ($fieldPath -match '^@([^.]+)\.') {
                    $expansionName = $matches[1]
                    [void]$expansions.Add($expansionName)
                    Write-Verbose "Found required expansion: $expansionName"
                }
            }
        }
    }

    return [PSCustomObject]@{
        Extensions = @($extensions)
        Expansions = @($expansions)
    }
}
