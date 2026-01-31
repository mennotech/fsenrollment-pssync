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
    Optional template metadata hashtable containing ColumnMappings with PowerSchoolAPIField mappings.

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
    This is a private helper function used by Submit-PSStudentChange and other functions.
    Maintains consistency with template-driven field mapping throughout the system.
#>
function Get-PowerSchoolFieldMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EntityProperty,

        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateMetadata
    )

    # Try to get mapping from template metadata first
    if ($TemplateMetadata -and $TemplateMetadata.ColumnMappings) {
        $mapping = $TemplateMetadata.ColumnMappings | Where-Object { $_.EntityProperty -eq $EntityProperty } | Select-Object -First 1
        if ($mapping -and $mapping.PowerSchoolAPIField) {
            return $mapping.PowerSchoolAPIField
        }
    }

    # Fallback to default field mappings for common student fields
    $defaultFieldMapping = @{
        'StudentNumber' = 'local_id'
        'SchoolID' = 'school_id'
        'FirstName' = 'name.first_name'
        'MiddleName' = 'name.middle_name'
        'LastName' = 'name.last_name'
        'GradeLevel' = 'grade_level'
        'Gender' = 'gender'
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
    }

    return $defaultFieldMapping[$EntityProperty]
}