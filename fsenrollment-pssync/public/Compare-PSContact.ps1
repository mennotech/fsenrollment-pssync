#Requires -Version 7.0

<#
.SYNOPSIS
    Compares CSV contact data with PowerSchool person data to detect changes.

.DESCRIPTION
    Analyzes contact data from CSV (normalized PSNormalizedData) against person data
    from PowerSchool PowerQuery (com.fsenrollment.dats.person) to identify new contacts 
    and updated contacts.
    Returns a structured change report.
    
    Only checks PSContact fields (FirstName, MiddleName, LastName, Gender, Employer) for changes.
    Email addresses, phone numbers, and addresses are not compared at this stage.
    
    Note: This function does NOT detect removed contacts (contacts in PowerSchool but not in CSV).
    It only identifies new contacts and updates to existing contacts.

.PARAMETER CsvData
    PSNormalizedData object containing contacts from CSV import.

.PARAMETER PowerSchoolData
    Array of person objects from PowerSchool PowerQuery (from Invoke-PowerQuery 
    -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords).

.PARAMETER TemplateConfig
    Template configuration object loaded from the template file. Used to determine
    key fields and fields to check for changes.

.PARAMETER MatchOn
    Property to use for matching contacts between CSV and PowerSchool. Default is determined
    by TemplateConfig.KeyField. If TemplateConfig is not provided, defaults to 'ContactID'.
    Currently supports 'ContactID' and 'ContactIdentifier'.

.OUTPUTS
    PSCustomObject with properties: New, Updated, Unchanged, Summary
    
    Note: The Removed collection is not included as this function does not detect removed contacts.

.EXAMPLE
    $csvData = Import-FSCsv -Path './contacts.csv' -TemplateName 'fs_powerschool_nonapi_report_parents'
    $psData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
    $templateConfig = Import-PowerSchoolDataFile './config/templates/fs_powerschool_nonapi_report_parents.psd1'
    
    $changes = Compare-PSContact -CsvData $csvData -PowerSchoolData $psData.Records -TemplateConfig $templateConfig
    
    Write-Host "New: $($changes.New.Count), Updated: $($changes.Updated.Count)"
    
    Compares contacts using the template configuration to determine key fields and comparison settings.

.NOTES
    This function performs field-by-field comparison to detect what changed.
    The Updated collection contains objects with OldValue and NewValue properties.
    Only PSContact entity fields are compared - email, phone, and address data are excluded.
#>
function Compare-PSContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSNormalizedData]$CsvData,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$PowerSchoolData,

        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateConfig,

        [Parameter(Mandatory = $false)]
        [ValidateSet('ContactID', 'ContactIdentifier')]
        [string]$MatchOn
    )

    begin {
        Write-Verbose "Starting contact comparison"
        
        # Determine matching configuration from template or defaults
        $columnMappings = @()
        if ($TemplateConfig) {
            $keyField = $TemplateConfig.KeyField ?? 'ContactID'
            $psKeyField = $TemplateConfig.PowerSchoolKeyField ?? 'person_id'
            $checkForChanges = $TemplateConfig.CheckForChanges ?? @('FirstName', 'MiddleName', 'LastName', 'Gender', 'Employer')
            
            # Get Contact entity column mappings from template
            if ($TemplateConfig.ColumnMappings -and $TemplateConfig.ColumnMappings.Contact) {
                $columnMappings = $TemplateConfig.ColumnMappings.Contact
            }
        } else {
            $keyField = 'ContactID'
            $psKeyField = 'person_id'
            $checkForChanges = @('FirstName', 'MiddleName', 'LastName', 'Gender', 'Employer')
        }
        
        # Override with MatchOn parameter if provided
        if ($MatchOn) {
            $keyField = $MatchOn
            # Set corresponding PowerSchool field based on match field
            switch ($MatchOn) {
                'ContactID' { $psKeyField = 'person_id' }
                'ContactIdentifier' { $psKeyField = $TemplateConfig.PowerSchoolKeyField ?? 'person_statecontactid' }
                default { $psKeyField = 'person_id' }
            }
        }
        
        Write-Verbose "Using CSV key field: $keyField"
        Write-Verbose "Using PowerSchool key field: $psKeyField"
        Write-Verbose "Fields to check for changes: $($checkForChanges -join ', ')"
        
        # Initialize result collections
        $newContacts = [System.Collections.Generic.List[PSCustomObject]]::new()
        $updatedContacts = [System.Collections.Generic.List[PSCustomObject]]::new()
        $unchangedContacts = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Create lookup dictionary for efficient comparison
        $psLookup = @{}
        foreach ($psPerson in $PowerSchoolData) {
            # Get the PowerSchool key value
            $psKeyValue = $psPerson.$psKeyField
            
            # Convert key to string for consistent dictionary lookup
            if ($null -ne $psKeyValue) {
                $key = $psKeyValue.ToString()
                
                if (-not [string]::IsNullOrWhiteSpace($key)) {
                    $psLookup[$key] = $psPerson
                }
            }
        }
        
        Write-Verbose "PowerSchool has $($psLookup.Count) persons indexed by $psKeyField"
        Write-Verbose "CSV has $($CsvData.Contacts.Count) contacts"
    }

    process {
        try {
            # Compare each CSV contact with PowerSchool person data
            foreach ($csvContact in $CsvData.Contacts) {
                # Get the match key value from CSV contact
                $matchKey = $csvContact.$keyField
                
                if ([string]::IsNullOrWhiteSpace($matchKey)) {
                    Write-Warning "CSV contact missing $keyField match field, skipping"
                    continue
                }
                
                if ($psLookup.ContainsKey($matchKey)) {
                    # Contact exists in PowerSchool - check for changes
                    $psPerson = $psLookup[$matchKey]
                    
                    # Pass checkForChanges array and columnMappings to Compare-ContactFields
                    $changes = Compare-ContactFields -CsvContact $csvContact -PowerSchoolPerson $psPerson -CheckForChanges $checkForChanges -ColumnMappings $columnMappings
                    
                    if ($changes.Count -gt 0) {
                        # Contact has changes
                        $updatedContacts.Add([PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = $keyField
                            CsvContact = $csvContact
                            PowerSchoolPerson = $psPerson
                            Changes = $changes
                        })
                        Write-Verbose "Contact $matchKey has $($changes.Count) field changes"
                    } else {
                        # Contact unchanged
                        $unchangedContacts.Add([PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = $keyField
                            Contact = $csvContact
                        })
                    }
                } else {
                    # Contact is new (not in PowerSchool)
                    $newContacts.Add([PSCustomObject]@{
                        MatchKey = $matchKey
                        MatchField = $keyField
                        Contact = $csvContact
                    })
                    Write-Verbose "Contact $matchKey is new (not in PowerSchool)"
                }
            }
            
            # Create summary (excluding removed contacts)
            $summary = [PSCustomObject]@{
                TotalInCsv = $CsvData.Contacts.Count
                TotalInPowerSchool = $PowerSchoolData.Count
                NewCount = $newContacts.Count
                UpdatedCount = $updatedContacts.Count
                UnchangedCount = $unchangedContacts.Count
                MatchField = $keyField
            }
            
            # Create result object (no Removed collection)
            $result = [PSCustomObject]@{
                New = $newContacts
                Updated = $updatedContacts
                Unchanged = $unchangedContacts
                Summary = $summary
            }
            
            Write-Verbose "Comparison complete: $($newContacts.Count) new, $($updatedContacts.Count) updated, $($unchangedContacts.Count) unchanged"
            
            return $result
        }
        catch {
            Write-Error "Failed to compare contact data: $_"
            throw
        }
    }

    end {
        Write-Verbose "Contact comparison completed"
    }
}
