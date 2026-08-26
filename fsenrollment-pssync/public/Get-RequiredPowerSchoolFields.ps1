#Requires -Version 7.0

<#
.SYNOPSIS
    Extracts required PowerSchool extensions and expansions from template metadata.

.DESCRIPTION
    Resolves the template's PowerSchool API map to determine which extensions and
    expansions are required to retrieve all mapped fields.
    
    NOTE: Most users don't need to call this function directly. Get-PowerSchoolStudent 
    automatically calls this function internally when you use -TemplateMetadata or -TemplateName.
    
    This function is useful for:
    - Advanced scenarios where you need to inspect required fields before retrieving data
    - Custom workflows that need field detection logic separate from data retrieval
    - Debugging template configurations
    
    Parses PowerSchoolAPIField values:
    - extension.table_name.field → adds 'table_name' to extensions
    - @expansion_name.field → adds 'expansion_name' to expansions

.PARAMETER TemplateMetadata
    Template metadata from PSNormalizedData. Maintained API maps are loaded from
    config/powerschool-maps.

.OUTPUTS
    PSCustomObject with properties: Extensions (array), Expansions (array)

.EXAMPLE
    # RECOMMENDED APPROACH: Let Get-PowerSchoolStudent handle detection automatically
    $csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    $students = Get-PowerSchoolStudent -All -TemplateMetadata $csvData.TemplateMetadata
    
    # Get-PowerSchoolStudent calls Get-RequiredPowerSchoolFields internally

.EXAMPLE
    # Advanced: Inspect required fields before retrieving data
    $csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    $required = Get-RequiredPowerSchoolFields -TemplateMetadata $csvData.TemplateMetadata
    
    Write-Host "This template requires:"
    Write-Host "  Extensions: $($required.Extensions -join ', ')"
    Write-Host "  Expansions: $($required.Expansions -join ', ')"
    
    # Then retrieve data
    $students = Get-PowerSchoolStudent -All -TemplateMetadata $csvData.TemplateMetadata

.NOTES
    Called internally by Get-PowerSchoolStudent when using -TemplateMetadata or -TemplateName.
    Returns empty arrays if no extensions or expansions are required.
#>
function Get-RequiredPowerSchoolFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$TemplateMetadata
    )

    $extensions = [System.Collections.Generic.HashSet[string]]::new()
    $expansions = [System.Collections.Generic.HashSet[string]]::new()

    if ($TemplateMetadata) {
        $columnMappings = Get-PowerSchoolApiMappings -TemplateMetadata $TemplateMetadata
        
        foreach ($mapping in $columnMappings) {
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
