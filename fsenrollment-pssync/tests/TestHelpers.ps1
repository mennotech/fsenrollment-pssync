#Requires -Version 7.0

<#
.SYNOPSIS
    Test helper functions for FSEnrollment-PSSync Pester tests.

.DESCRIPTION
    Provides utility functions for creating consistent mock data and test fixtures
    across all Pester tests. Ensures test data structures match production behavior.
    
    NOTE: This file is intended to be dot-sourced or copied into test BeforeAll blocks.
    The New-MockTemplateMetadata function must be defined in both global scope and
    InModuleScope for tests that use InModuleScope blocks.

.EXAMPLE
    # In test BeforeAll block:
    BeforeAll {
        Import-Module $ModulePath -Force
        
        # Define helper in both scopes
        function global:New-MockTemplateMetadata {
            param([hashtable]$Config)
            return $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
        
        InModuleScope FSEnrollment-PSSync {
            function New-MockTemplateMetadata {
                param([hashtable]$Config)
                return $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            }
        }
    }
#>

<#
.SYNOPSIS
    Creates a normalized TemplateMetadata object for use in tests.

.DESCRIPTION
    Converts a hashtable configuration to a PSCustomObject via JSON round-trip,
    matching the behavior of Import-FSCsv. This ensures test mocks use the same
    data structure as production code.
    
    This function should be defined in test BeforeAll blocks in both global scope
    (using 'function global:New-MockTemplateMetadata') and module scope (within
    InModuleScope block) for tests that use InModuleScope.

.PARAMETER Config
    Hashtable containing the template configuration (TemplateName, ColumnMappings, etc.)

.OUTPUTS
    PSCustomObject representing normalized template metadata.

.EXAMPLE
    $templateMetadata = New-MockTemplateMetadata @{
        TemplateName = 'test_contact_template'
        KeyField = 'ContactID'
        PowerSchoolKeyField = 'person_id'
        CheckForChanges = @('FirstName', 'LastName', 'Gender')
        ColumnMappings = @(
            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'person_firstname' }
        )
    }

.NOTES
    This function mimics the JSON normalization performed in Import-FSCsv (line 155-159).
    All TemplateMetadata objects in tests should be created using this helper to ensure
    consistency with production behavior where hashtables are converted to PSCustomObject.
#>
function New-MockTemplateMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    # Normalize through JSON round-trip to match Import-FSCsv behavior
    # This converts hashtables to PSCustomObject for consistent type handling
    return $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}
