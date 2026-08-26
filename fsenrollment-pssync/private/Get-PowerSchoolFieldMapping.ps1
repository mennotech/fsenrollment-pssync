#Requires -Version 7.0

<#
.SYNOPSIS
    Gets the PowerSchool API field mapping for an entity property from template metadata.

.DESCRIPTION
    This private helper function looks up the PowerSchoolAPIField mapping for a given entity 
    property from template metadata. Provides a fallback to default mappings if template 
    metadata is not available.

.PARAMETER EntityProperty
    The name of the entity property to get the PowerSchool API field for (e.g., 'FirstName', 'MiddleName').

.PARAMETER TemplateMetadata
    Optional template metadata containing ColumnMappings with PowerSchoolAPIField mappings.

.OUTPUTS
    String representing the PowerSchool API field name, or $null if no mapping found.

.EXAMPLE
    $apiField = Get-PowerSchoolFieldMapping -EntityProperty 'FirstName' -TemplateMetadata $template
    # Returns: 'name.first_name'

.EXAMPLE
    # Without template metadata, falls back to defaults
    $apiField = Get-PowerSchoolFieldMapping -EntityProperty 'FirstName'
    # Returns: 'name.first_name'

.NOTES
    Private helper function for Submit-PSStudentChange and Submit-PSContactChange.
    Maintains consistency with template-driven field mapping throughout the system.
#>
function Get-PowerSchoolFieldMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EntityProperty,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$TemplateMetadata
    )

    # Try to get mapping from template metadata first
    if ($TemplateMetadata) {
        $columnMappings = Get-PowerSchoolApiMappings -TemplateMetadata $TemplateMetadata
        
        # Find mapping with PowerSchoolAPIField defined (skip mappings without API field)
        # This is important for fields that appear in multiple entities (e.g., ContactIdentifier)
        # where only one entity has the PowerSchoolAPIField defined
        $mapping = $columnMappings | Where-Object {
            $_.EntityProperty -eq $EntityProperty -and 
            $_.PowerSchoolAPIField 
        } | Select-Object -First 1
        
        if ($mapping) {
            return $mapping.PowerSchoolAPIField
        }
    }

    # Fallback to default field mappings for common student and contact fields
    # NOTE: These defaults are for Student API (v1) which uses nested structures.
    # Contact API uses flat field names (firstName, middleName, lastName).
    # Templates should define their own ColumnMappings in TemplateMetadata for proper mapping.
    # These defaults are only used when TemplateMetadata is not provided or incomplete.
    $defaultFieldMapping = @{
        # Student-specific fields (use nested structure for v1 API)
        'StudentNumber' = 'local_id'
        'SchoolID' = 'school_id'
        'GradeLevel' = 'grade_level'
        'DOB' = 'dob'
        'EnrollStatus' = 'enroll_status'
        'EntryDate' = 'entrydate'
        'ExitDate' = 'exitdate'
        'HomePhone' = 'home_phone'
        'Street' = 'street'
        'City' = 'city'
        'State' = 'state'
        'Zip' = 'zip'
        'MailingStreet' = 'mailing_street'
        'MailingCity' = 'mailing_city'
        'MailingState' = 'mailing_state'
        'MailingZip' = 'mailing_zip'
        'FamilyIdent' = 'family_ident'
        'TransferComment' = 'transfer_comment'
        
        # Shared name fields - defaults use Student API pattern (nested under 'name')
        # Contact API overrides these with flat names in template
        'FirstName' = 'name.first_name'
        'MiddleName' = 'name.middle_name'
        'LastName' = 'name.last_name'
        'Gender' = 'gender'
        
        # Contact-specific fields (flat structure) - should be defined in template
        'Prefix' = 'prefix'
        'Suffix' = 'suffix'
        'Employer' = 'employer'
    }

    return $defaultFieldMapping[$EntityProperty]
}