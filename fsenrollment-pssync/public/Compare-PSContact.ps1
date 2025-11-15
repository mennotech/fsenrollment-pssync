#Requires -Version 7.0

<#
.SYNOPSIS
    Compares CSV contact data with PowerSchool person data to detect changes.

.DESCRIPTION
    Analyzes contact data from CSV (normalized PSNormalizedData) against person data
    from PowerSchool PowerQuery (com.fsenrollment.dats.person) to identify new contacts 
    and updated contacts.
    Returns a structured change report.
    
    Checks PSContact fields (FirstName, MiddleName, LastName, Gender, Employer) for changes.
    Optionally compares email addresses, phone numbers, and addresses if PowerQuery data is provided.
    
    Note: This function does NOT detect removed contacts (contacts in PowerSchool but not in CSV).
    It only identifies new contacts and updates to existing contacts.

.PARAMETER CsvData
    PSNormalizedData object containing contacts from CSV import.

.PARAMETER PowerSchoolData
    Array of person objects from PowerSchool PowerQuery (from Invoke-PowerQuery 
    -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords).

.PARAMETER PowerSchoolEmailData
    Optional. Array of email objects from PowerSchool PowerQuery (from Invoke-PowerQuery 
    -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords).
    If provided, email addresses will be compared for changes.

.PARAMETER PowerSchoolPhoneData
    Optional. Array of phone objects from PowerSchool PowerQuery (from Invoke-PowerQuery 
    -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords).
    If provided, phone numbers will be compared for changes.

.PARAMETER PowerSchoolAddressData
    Optional. Array of address objects from PowerSchool PowerQuery (from Invoke-PowerQuery 
    -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords).
    If provided, addresses will be compared for changes.

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
    $templateConfig = Import-PowerShellDataFile './config/templates/fs_powerschool_nonapi_report_parents.psd1'
    
    $changes = Compare-PSContact -CsvData $csvData -PowerSchoolData $psData.Records -TemplateConfig $templateConfig
    
    Write-Host "New: $($changes.New.Count), Updated: $($changes.Updated.Count)"
    
    Compares contacts using the template configuration to determine key fields and comparison settings.

.EXAMPLE
    # Compare with email, phone, and address data
    $csvData = Import-FSCsv -Path './contacts.csv' -TemplateName 'fs_powerschool_nonapi_report_parents'
    $psPersonData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
    $psEmailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
    $psPhoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
    $psAddressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
    $templateConfig = Import-PowerShellDataFile './config/templates/fs_powerschool_nonapi_report_parents.psd1'
    
    $changes = Compare-PSContact -CsvData $csvData `
        -PowerSchoolData $psPersonData.Records `
        -PowerSchoolEmailData $psEmailData.Records `
        -PowerSchoolPhoneData $psPhoneData.Records `
        -PowerSchoolAddressData $psAddressData.Records `
        -TemplateConfig $templateConfig
    
    Compares contacts including email addresses, phone numbers, and addresses.

.NOTES
    This function performs field-by-field comparison to detect what changed.
    The Updated collection contains objects with OldValue and NewValue properties.
    PSContact entity fields are always compared. Email, phone, and address data are compared
    only if the corresponding PowerQuery data is provided via parameters.
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
        [AllowEmptyCollection()]
        [array]$PowerSchoolEmailData = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [array]$PowerSchoolPhoneData = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [array]$PowerSchoolAddressData = @(),

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
            
            # Get CheckForChanges from EntityTypeMap.Contact or fall back to top-level or default
            if ($TemplateConfig.EntityTypeMap -and $TemplateConfig.EntityTypeMap.Contact -and $TemplateConfig.EntityTypeMap.Contact.CheckForChanges) {
                $checkForChanges = $TemplateConfig.EntityTypeMap.Contact.CheckForChanges
            } elseif ($TemplateConfig.CheckForChanges) {
                # Fallback to top-level for backward compatibility
                $checkForChanges = $TemplateConfig.CheckForChanges
            } else {
                $checkForChanges = @('FirstName', 'MiddleName', 'LastName', 'Gender', 'Employer')
            }
            
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
        
        # Create lookup dictionaries for email, phone, and address data by person_id
        $psEmailLookup = @{}
        $psPhoneLookup = @{}
        $psAddressLookup = @{}
        
        if ($PowerSchoolEmailData.Count -gt 0) {
            Write-Verbose "Creating email lookup dictionary from $($PowerSchoolEmailData.Count) email records"
            foreach ($email in $PowerSchoolEmailData) {
                $personKey = $email.person_id.ToString()
                if (-not $psEmailLookup.ContainsKey($personKey)) {
                    $psEmailLookup[$personKey] = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                $psEmailLookup[$personKey].Add($email)
            }
            Write-Verbose "Indexed emails for $($psEmailLookup.Count) persons"
        }
        
        if ($PowerSchoolPhoneData.Count -gt 0) {
            Write-Verbose "Creating phone lookup dictionary from $($PowerSchoolPhoneData.Count) phone records"
            foreach ($phone in $PowerSchoolPhoneData) {
                $personKey = $phone.person_id.ToString()
                if (-not $psPhoneLookup.ContainsKey($personKey)) {
                    $psPhoneLookup[$personKey] = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                $psPhoneLookup[$personKey].Add($phone)
            }
            Write-Verbose "Indexed phones for $($psPhoneLookup.Count) persons"
        }
        
        if ($PowerSchoolAddressData.Count -gt 0) {
            Write-Verbose "Creating address lookup dictionary from $($PowerSchoolAddressData.Count) address records"
            foreach ($address in $PowerSchoolAddressData) {
                $personKey = $address.person_id.ToString()
                if (-not $psAddressLookup.ContainsKey($personKey)) {
                    $psAddressLookup[$personKey] = [System.Collections.Generic.List[PSCustomObject]]::new()
                }
                $psAddressLookup[$personKey].Add($address)
            }
            Write-Verbose "Indexed addresses for $($psAddressLookup.Count) persons"
        }
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
                    $personId = $psPerson.person_id.ToString()
                    
                    # Pass checkForChanges array and columnMappings to Compare-ContactFields
                    $changes = Compare-ContactFields -CsvContact $csvContact -PowerSchoolPerson $psPerson -CheckForChanges $checkForChanges -ColumnMappings $columnMappings
                    
                    # Compare emails if data is available
                    $emailChanges = $null
                    if ($PowerSchoolEmailData.Count -gt 0 -or $CsvData.EmailAddresses.Count -gt 0) {
                        # Get CSV emails for this contact
                        $csvEmails = $CsvData.EmailAddresses | Where-Object { $_.ContactIdentifier -eq $matchKey }
                        
                        # Get PowerSchool emails for this person
                        $psEmails = if ($psEmailLookup.ContainsKey($personId)) { $psEmailLookup[$personId] } else { @() }
                        
                        $emailChanges = Compare-ContactEmailFields -CsvEmails $csvEmails -PowerSchoolEmails $psEmails -ContactIdentifier $matchKey
                        Write-Verbose "Contact ${matchKey}: Email changes - Added: $($emailChanges.Added.Count), Modified: $($emailChanges.Modified.Count), Removed: $($emailChanges.Removed.Count)"
                    }
                    
                    # Compare phones if data is available
                    $phoneChanges = $null
                    if ($PowerSchoolPhoneData.Count -gt 0 -or $CsvData.PhoneNumbers.Count -gt 0) {
                        # Get CSV phones for this contact
                        $csvPhones = $CsvData.PhoneNumbers | Where-Object { $_.ContactIdentifier -eq $matchKey }
                        
                        # Get PowerSchool phones for this person
                        $psPhones = if ($psPhoneLookup.ContainsKey($personId)) { $psPhoneLookup[$personId] } else { @() }
                        
                        $phoneChanges = Compare-ContactPhoneFields -CsvPhones $csvPhones -PowerSchoolPhones $psPhones -ContactIdentifier $matchKey
                        Write-Verbose "Contact ${matchKey}: Phone changes - Added: $($phoneChanges.Added.Count), Modified: $($phoneChanges.Modified.Count), Removed: $($phoneChanges.Removed.Count)"
                    }
                    
                    # Compare addresses if data is available
                    $addressChanges = $null
                    if ($PowerSchoolAddressData.Count -gt 0 -or $CsvData.Addresses.Count -gt 0) {
                        # Get CSV addresses for this contact
                        $csvAddresses = $CsvData.Addresses | Where-Object { $_.ContactIdentifier -eq $matchKey }
                        
                        # Get PowerSchool addresses for this person
                        $psAddresses = if ($psAddressLookup.ContainsKey($personId)) { $psAddressLookup[$personId] } else { @() }
                        
                        $addressChanges = Compare-ContactAddressFields -CsvAddresses $csvAddresses -PowerSchoolAddresses $psAddresses -ContactIdentifier $matchKey
                        Write-Verbose "Contact ${matchKey}: Address changes - Added: $($addressChanges.Added.Count), Modified: $($addressChanges.Modified.Count), Removed: $($addressChanges.Removed.Count)"
                    }
                    
                    # Determine if contact has any changes
                    $hasChanges = $changes.Count -gt 0 -or 
                                  ($emailChanges -and ($emailChanges.Added.Count -gt 0 -or $emailChanges.Modified.Count -gt 0 -or $emailChanges.Removed.Count -gt 0)) -or
                                  ($phoneChanges -and ($phoneChanges.Added.Count -gt 0 -or $phoneChanges.Modified.Count -gt 0 -or $phoneChanges.Removed.Count -gt 0)) -or
                                  ($addressChanges -and ($addressChanges.Added.Count -gt 0 -or $addressChanges.Modified.Count -gt 0 -or $addressChanges.Removed.Count -gt 0))
                    
                    if ($hasChanges) {
                        # Contact has changes
                        $updateRecord = [PSCustomObject]@{
                            MatchKey = $matchKey
                            MatchField = $keyField
                            CsvContact = $csvContact
                            PowerSchoolPerson = $psPerson
                            Changes = $changes
                        }
                        
                        # Add email, phone, address changes if they exist
                        if ($emailChanges) {
                            $updateRecord | Add-Member -NotePropertyName 'EmailChanges' -NotePropertyValue $emailChanges
                        }
                        if ($phoneChanges) {
                            $updateRecord | Add-Member -NotePropertyName 'PhoneChanges' -NotePropertyValue $phoneChanges
                        }
                        if ($addressChanges) {
                            $updateRecord | Add-Member -NotePropertyName 'AddressChanges' -NotePropertyValue $addressChanges
                        }
                        
                        $updatedContacts.Add($updateRecord)
                        Write-Verbose "Contact $matchKey has changes"
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
