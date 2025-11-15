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

.PARAMETER MatchOn
    Property to use for matching contacts between CSV and PowerSchool. Default is 'ContactID'.
    Currently only 'ContactID' is supported (matches against 'person_id' in PowerQuery results).

.OUTPUTS
    PSCustomObject with properties: New, Updated, Unchanged, Summary
    
    Note: The Removed collection is not included as this function does not detect removed contacts.

.EXAMPLE
    $csvData = Import-FSCsv -Path './contacts.csv' -TemplateName 'fs_powerschool_contacts'
    $psData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
    
    $changes = Compare-PSContact -CsvData $csvData -PowerSchoolData $psData.Records
    
    Write-Host "New: $($changes.New.Count), Updated: $($changes.Updated.Count)"
    
    Compares contacts using the person PowerQuery data from PowerSchool.

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
        [ValidateSet('ContactID')]
        [string]$MatchOn = 'ContactID'
    )

    begin {
        Write-Verbose "Starting contact comparison"
        
        # Default matching configuration
        $keyField = 'ContactID'  # CSV field
        $psKeyField = 'person_id'  # PowerSchool PowerQuery field
        $checkForChanges = @('FirstName', 'MiddleName', 'LastName', 'Gender', 'Employer')
        
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
                    
                    # Pass checkForChanges array to Compare-ContactFields
                    $changes = Compare-ContactFields -CsvContact $csvContact -PowerSchoolPerson $psPerson -CheckForChanges $checkForChanges
                    
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
