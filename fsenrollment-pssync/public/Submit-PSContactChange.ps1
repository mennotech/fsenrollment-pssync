#Requires -Version 7.0

<#
.SYNOPSIS
    Applies contact changes to PowerSchool based on comparison results.

.DESCRIPTION
    Takes the output from Compare-PSContact (either as an object or from a JSON file)
    and applies the changes to PowerSchool via Contact API calls. Supports creating new contacts
    and updating existing contacts.
    
    Includes robust error handling, retry logic, and the ability to limit the number
    of changes for testing purposes.
    
    Phase 1: Demographic changes (firstName, lastName, middleName, prefix, suffix, gender, employer)
    Phase 2: Email addresses, phone numbers, and addresses (for both new and updated contacts)
    Phase 3: Student-contact relationships (future)

.PARAMETER Changes
    PSCustomObject containing the comparison results from Compare-PSContact.
    Must have New, Updated, and TemplateMetadata properties.
    TemplateMetadata is required for field mapping and must be included in the Changes object.

.PARAMETER JsonPath
    Path to a JSON file containing the comparison results.
    Alternative to providing Changes parameter.
    The JSON file must include TemplateMetadata for field mapping.

.PARAMETER Limit
    Maximum number of changes to apply. Useful for testing with live data.
    Default is unlimited (applies all changes).

.PARAMETER Skip
    Number of changes to skip before starting to apply changes.
    Useful for resuming processing or batch processing large change files.
    Default is 0 (start from beginning).
    Works in combination with -Limit for batch processing.

.PARAMETER WhatIf
    Performs a dry run without making actual changes to PowerSchool.
    Displays detailed preview of what would be changed, including:
    - API endpoints that would be called
    - Field-by-field changes with old and new values
    - PowerSchool API field mappings
    - Complete JSON payloads that would be sent
    Use with -Verbose for full details. No PowerSchool connection required for preview.

.PARAMETER MaxRetries
    Maximum number of retry attempts for failed API calls. Default is 3.

.PARAMETER RetryDelaySeconds
    Initial retry delay in seconds. Default is 5.

.OUTPUTS
    PSCustomObject with properties:
    - NewContactsApplied: Number of new contacts successfully created
    - UpdatedContactsApplied: Number of contacts successfully updated
    - FailedChanges: List of changes that failed to apply
    - ProcessedCount: Total changes processed
    - Summary: Summary statistics

.EXAMPLE
    # Apply all changes from a comparison result
    $changes = Compare-PSContact -CsvData $csvData -PowerSchoolData $psData
    $result = Submit-PSContactChange -Changes $changes
    Write-Host "Applied $($result.NewContactsApplied) new and $($result.UpdatedContactsApplied) updated contacts"

.EXAMPLE
    # Apply changes from a JSON file with a limit for testing
    $result = Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -Limit 5
    Write-Host "Test run: Applied $($result.Summary.TotalApplied) of 5 changes"

.EXAMPLE
    # Skip first 10 changes and apply next 5 (useful for batch processing)
    $result = Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -Skip 10 -Limit 5
    Write-Host "Batch run: Applied changes 11-15"

.EXAMPLE
    # Resume processing from where you left off
    Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -Skip 50 -Limit 25

.EXAMPLE
    # Dry run to preview changes without applying them (use with -Verbose for full details)
    Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -WhatIf -Verbose
    
    # Output shows API endpoints, field changes, and complete JSON payloads
    # Summary shows 0 applied since no changes are made in WhatIf mode

.EXAMPLE
    # Apply changes with custom retry settings
    Submit-PSContactChange -Changes $changes -MaxRetries 5 -RetryDelaySeconds 10

.EXAMPLE
    # Complete workflow from CSV import to applying changes
    $csvData = Import-FSCsv -Path './contacts.csv' -TemplateName 'fs_powerschool_nonapi_report_parents'
    $psData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
    $templateConfig = Import-PowerShellDataFile './config/templates/fs_powerschool_nonapi_report_parents.psd1'
    $changes = Compare-PSContact -CsvData $csvData -PowerSchoolData $psData.Records -TemplateConfig $templateConfig
    Submit-PSContactChange -Changes $changes

.NOTES
    Requires an active PowerSchool connection (Connect-PowerSchool must be called first).
    Uses the PowerSchool Contacts API endpoints for creating and updating contacts.
    
    Phase 1: Demographics (firstName, lastName, middleName, prefix, suffix, gender, employer)
    Phase 2: Email addresses, phone numbers, and addresses - IMPLEMENTED
    Phase 3: Student-contact relationships (future)
    
    TemplateMetadata is required and must be included in the Changes object from Compare-PSContact.
    All field mappings are driven by the template configuration - no hardcoded mappings exist.
    
    API Endpoints:
    - POST /ws/contacts/contact - Create new contact (with demographics, emails, phones, addresses)
    - PUT /ws/contacts/{contactId}/demographics - Update contact demographics
    - PUT /ws/contacts/{contactId} - Update contact emails, phones, or addresses
#>
function Submit-PSContactChange {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Object')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Object', ValueFromPipeline = $true)]
        [PSCustomObject]$Changes,

        [Parameter(Mandatory = $true, ParameterSetName = 'Json')]
        [ValidateScript({ Test-Path $_ })]
        [string]$JsonPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit = [int]::MaxValue,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Skip = 0,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 300)]
        [int]$RetryDelaySeconds = 5
    )

    begin {
        Write-Verbose "Starting Submit-PSContactChange"
        
        # Check if connected to PowerSchool (skip for WhatIf to allow preview without connection)
        if (-not $WhatIfPreference) {
            if (-not $script:PowerSchoolToken -or -not $script:PowerSchoolBaseUrl) {
                throw "Not connected to PowerSchool. Please run Connect-PowerSchool first."
            }
        }
        
        # Initialize result tracking
        $script:ApplyResults = [PSCustomObject]@{
            NewContactsApplied = 0
            UpdatedContactsApplied = 0
            FailedChanges = [System.Collections.Generic.List[PSCustomObject]]::new()
            ProcessedCount = 0
        }
    }

    process {
        try {
            # Load changes from JSON if path provided
            if ($PSCmdlet.ParameterSetName -eq 'Json') {
                Write-Verbose "Loading changes from JSON file: $JsonPath"
                $jsonContent = Get-Content -Path $JsonPath -Raw
                $Changes = $jsonContent | ConvertFrom-Json
            }

            # Validate input structure
            if (-not $Changes.PSObject.Properties['New'] -or -not $Changes.PSObject.Properties['Updated']) {
                throw "Invalid changes object. Must contain 'New' and 'Updated' properties."
            }
            
            # Extract and validate TemplateMetadata from Changes object
            if (-not $Changes.PSObject.Properties['TemplateMetadata'] -or -not $Changes.TemplateMetadata) {
                throw "TemplateMetadata not found in Changes object. Ensure you're passing output from Compare-PSContact which includes template metadata."
            }
            
            # Use TemplateMetadata directly
            $TemplateMetadata = $Changes.TemplateMetadata
            Write-Verbose "Using TemplateMetadata from Changes object (Template: $($TemplateMetadata.TemplateName))"

            # Calculate total changes to apply
            $totalChanges = $Changes.New.Count + $Changes.Updated.Count
            $availableChanges = [Math]::Max(0, $totalChanges - $Skip)
            $changesToApply = [Math]::Min($availableChanges, $Limit)
            
            Write-Verbose "Total changes available: $totalChanges (New: $($Changes.New.Count), Updated: $($Changes.Updated.Count))"
            if ($Skip -gt 0) {
                Write-Verbose "Skipping first $Skip changes"
                Write-Verbose "Remaining changes after skip: $availableChanges"
            }
            Write-Verbose "Changes to apply (with limit): $changesToApply"

            if ($WhatIfPreference) {
                if ($Skip -gt 0) {
                    Write-Host "WhatIf: Would skip $Skip changes and apply $changesToApply of remaining $availableChanges changes" -ForegroundColor Yellow
                } else {
                    Write-Host "WhatIf: Would apply $changesToApply of $totalChanges changes" -ForegroundColor Yellow
                }
            }

            $changeNumber = 0
            $processedNumber = 0
            $processedNumber = 0

            # Process new contacts
            foreach ($newContact in $Changes.New) {
                $processedNumber++
                
                # Skip if we haven't reached the skip threshold yet
                if ($processedNumber -le $Skip) {
                    Write-Verbose "Skipping new contact $processedNumber (skip threshold: $Skip)"
                    continue
                }
                
                if ($changeNumber -ge $Limit) {
                    Write-Verbose "Reached limit of $Limit changes, stopping"
                    break
                }
                
                $changeNumber++
                Write-Progress -Activity "Applying Contact Changes" `
                    -Status "Processing new contact $changeNumber of $changesToApply" `
                    -PercentComplete (($changeNumber / $changesToApply) * 100)

                try {
                    $contact = $newContact.Contact
                    $matchKey = $newContact.MatchKey
                    
                    # Get related entities from the new contact record
                    $emailAddresses = if ($newContact.PSObject.Properties['EmailAddresses']) { $newContact.EmailAddresses } else { @() }
                    $phoneNumbers = if ($newContact.PSObject.Properties['PhoneNumbers']) { $newContact.PhoneNumbers } else { @() }
                    $addresses = if ($newContact.PSObject.Properties['Addresses']) { $newContact.Addresses } else { @() }
                    $relationships = if ($newContact.PSObject.Properties['Relationships']) { $newContact.Relationships } else { @() }
                    
                    # Build contact payload for API (always build for detailed display)
                    $payload = Build-ContactPayload -Contact $contact `
                        -TemplateMetadata $TemplateMetadata `
                        -EmailAddresses $emailAddresses `
                        -PhoneNumbers $phoneNumbers `
                        -Addresses $addresses `
                        -Relationships $relationships
                    
                    if ($WhatIfPreference) {
                        Write-Host "`n=== WHATIF: New Contact Creation ===" -ForegroundColor Cyan
                        Write-Host "Contact: $matchKey ($($contact.FirstName) $($contact.LastName))" -ForegroundColor Yellow
                        Write-Verbose "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/contacts/contact"
                        
                        # Show field details for new contact - iterate dynamically
                        Write-Host "Contact Fields to Create:" -ForegroundColor Gray
                        
                        # Display contact fields (payload is flat structure for Contact API)
                        foreach ($key in ($payload.Keys | Sort-Object)) {
                            $value = $payload[$key]
                            if ($null -ne $value -and $value -ne '') {
                                # Format the field name for display (convert to title case)
                                $uppercaseKey = ($key -replace '_', ' ').ToUpper()
                                $displayName = (Get-Culture).TextInfo.ToTitleCase($uppercaseKey.ToLower())
                                Write-Host "  ${displayName}: $value" -ForegroundColor White
                            }
                        }
                        
                        # Only show full payload with -Verbose
                        Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10)"
                    }
                    
                    if ($PSCmdlet.ShouldProcess("New Contact: $matchKey ($($contact.FirstName) $($contact.LastName))", "Create in PowerSchool")) {
                        if (-not $WhatIfPreference) {
                            Write-Verbose "Creating new contact: $matchKey"
                            Write-Verbose "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/contacts/contact"
                            Write-Verbose "Contact fields being created:"
                            
                            # Display contact fields (payload is flat structure for Contact API)
                            foreach ($key in ($payload.Keys | Sort-Object)) {
                                $value = $payload[$key]
                                if ($null -ne $value -and $value -ne '') {
                                    Write-Verbose "  ${key}: $value"
                                }
                            }
                            
                            Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10 -Compress)"
                            
                            # Make API call to create contact
                            $result = Invoke-CreateContact -Payload $payload -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                            
                            if ($result.Success) {
                                $script:ApplyResults.NewContactsApplied++
                                Write-Host "✓ Created new contact: $matchKey ($($contact.FirstName) $($contact.LastName))" -ForegroundColor Green
                                Write-Verbose "Successfully created contact with API response: $($result.Response | ConvertTo-Json -Depth 10 -Compress)"
                            } else {
                                throw $result.Error
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to create new contact $matchKey : $_"
                    $script:ApplyResults.FailedChanges.Add([PSCustomObject]@{
                        Type = 'New'
                        MatchKey = $matchKey
                        Contact = $newContact.Contact
                        Error = $_.Exception.Message
                    })
                }
                
                $script:ApplyResults.ProcessedCount++
            }

            # Process updated contacts
            foreach ($updatedContact in $Changes.Updated) {
                # Phase 2: Now handles demographic changes, email changes, phone changes, and address changes
                $matchKey = $updatedContact.MatchKey
                $changes = $updatedContact.Changes
                $emailChanges = $updatedContact.EmailChanges
                $phoneChanges = $updatedContact.PhoneChanges
                $addressChanges = $updatedContact.AddressChanges
                
                # Determine if this contact has any changes to process
                $hasDemographicChanges = $changes -and (($changes -is [array] -and $changes.Count -gt 0) -or ($changes -isnot [array]))
                $hasEmailChanges = $emailChanges -and ($emailChanges.Added.Count -gt 0 -or $emailChanges.Modified.Count -gt 0 -or $emailChanges.Removed.Count -gt 0)
                $hasPhoneChanges = $phoneChanges -and ($phoneChanges.Added.Count -gt 0 -or $phoneChanges.Modified.Count -gt 0 -or $phoneChanges.Removed.Count -gt 0)
                $hasAddressChanges = $addressChanges -and ($addressChanges.Added.Count -gt 0 -or $addressChanges.Modified.Count -gt 0 -or $addressChanges.Removed.Count -gt 0)
                
                # Skip if no changes at all
                if (-not ($hasDemographicChanges -or $hasEmailChanges -or $hasPhoneChanges -or $hasAddressChanges)) {
                    Write-Verbose "Skipping contact $matchKey - no changes to apply"
                    continue
                }
                
                $processedNumber++
                
                # Skip if we haven't reached the skip threshold yet
                if ($processedNumber -le $Skip) {
                    Write-Verbose "Skipping updated contact $processedNumber (skip threshold: $Skip)"
                    continue
                }
                
                if ($changeNumber -ge $Limit) {
                    Write-Verbose "Reached limit of $Limit changes, stopping"
                    break
                }
                
                $changeNumber++
                Write-Progress -Activity "Applying Contact Changes" `
                    -Status "Processing updated contact $changeNumber of $changesToApply" `
                    -PercentComplete (($changeNumber / $changesToApply) * 100)

                try {
                    $psPerson = $updatedContact.PowerSchoolPerson
                    
                    # Get contact person_id (ContactID) for update
                    $contactId = $psPerson.person_id
                    if (-not $contactId) {
                        throw "PowerSchool contact person_id (ContactID) not found for $matchKey"
                    }
                    
                    # Build readable update message
                    $contactName = "$($psPerson.person_firstname) $($psPerson.person_middlename) $($psPerson.person_lastname)".Trim()
                    $changeParts = @()
                    if ($hasDemographicChanges) {
                        if ($changes -isnot [array]) { $changes = @($changes) }
                        $changeParts += "$($changes.Count) demographic field(s)"
                    }
                    if ($hasEmailChanges) {
                        $emailCount = $emailChanges.Added.Count + $emailChanges.Modified.Count + $emailChanges.Removed.Count
                        $changeParts += "$emailCount email change(s)"
                    }
                    if ($hasPhoneChanges) {
                        $phoneCount = $phoneChanges.Added.Count + $phoneChanges.Modified.Count + $phoneChanges.Removed.Count
                        $changeParts += "$phoneCount phone change(s)"
                    }
                    if ($hasAddressChanges) {
                        $addressCount = $addressChanges.Added.Count + $addressChanges.Modified.Count + $addressChanges.Removed.Count
                        $changeParts += "$addressCount address change(s)"
                    }
                    $updateMessage = "Contact: $matchKey (ContactID: $contactId) Name: $contactName - $($changeParts -join ', ')"
                    
                    # Process demographic changes if present
                    if ($hasDemographicChanges) {
                        if ($changes -isnot [array]) { $changes = @($changes) }
                        $payload = Build-ContactUpdatePayload -Changes $changes -ContactID $contactId -PowerSchoolPerson $psPerson -TemplateMetadata $TemplateMetadata
                        
                        if ($WhatIfPreference) {
                            Write-Verbose "API Endpoint: PUT $($script:PowerSchoolBaseUrl)/ws/contacts/$contactId/demographics"
                            Write-Verbose "Demographic Field Changes ($($changes.Count) total):"
                            foreach ($change in $changes) {
                                Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                            }
                            Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10)"
                        }
                        
                        if ($PSCmdlet.ShouldProcess("Demographic changes for $matchKey", "Update in PowerSchool")) {
                            if (-not $WhatIfPreference) {
                                Write-Verbose "Updating contact demographics: $matchKey (ContactID: $contactId)"
                                $result = Invoke-UpdateContact -ContactID $contactId -Payload $payload -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                                
                                if (-not $result.Success) {
                                    throw "Demographics update failed: $($result.Error)"
                                }
                                Write-Verbose "Successfully updated demographics"
                            }
                        }
                    }
                    
                    # Process email changes if present (Phase 2)
                    if ($hasEmailChanges) {
                        if ($WhatIfPreference) {
                            Write-Verbose "Email Changes:"
                            Write-Verbose "  Added: $($emailChanges.Added.Count)"
                            Write-Verbose "  Modified: $($emailChanges.Modified.Count)"
                            Write-Verbose "  Removed: $($emailChanges.Removed.Count)"
                        }
                        
                        if ($PSCmdlet.ShouldProcess("Email changes for $matchKey", "Update in PowerSchool")) {
                            if (-not $WhatIfPreference) {
                                $emailResult = Invoke-UpdateContactEmails -ContactID $contactId -EmailChanges $emailChanges -TemplateMetadata $TemplateMetadata -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                                if (-not $emailResult.Success) {
                                    Write-Warning "Email update failed: $($emailResult.Error)"
                                }
                            }
                        }
                    }
                    
                    # Process phone changes if present (Phase 2)
                    if ($hasPhoneChanges) {
                        if ($WhatIfPreference) {
                            Write-Verbose "Phone Changes:"
                            Write-Verbose "  Added: $($phoneChanges.Added.Count)"
                            Write-Verbose "  Modified: $($phoneChanges.Modified.Count)"
                            Write-Verbose "  Removed: $($phoneChanges.Removed.Count)"
                        }
                        
                        if ($PSCmdlet.ShouldProcess("Phone changes for $matchKey", "Update in PowerSchool")) {
                            if (-not $WhatIfPreference) {
                                $phoneResult = Invoke-UpdateContactPhones -ContactID $contactId -PhoneChanges $phoneChanges -TemplateMetadata $TemplateMetadata -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                                if (-not $phoneResult.Success) {
                                    Write-Warning "Phone update failed: $($phoneResult.Error)"
                                }
                            }
                        }
                    }
                    
                    # Process address changes if present (Phase 2)
                    if ($hasAddressChanges) {
                        if ($WhatIfPreference) {
                            Write-Verbose "Address Changes:"
                            Write-Verbose "  Added: $($addressChanges.Added.Count)"
                            Write-Verbose "  Modified: $($addressChanges.Modified.Count)"
                            Write-Verbose "  Removed: $($addressChanges.Removed.Count)"
                        }
                        
                        if ($PSCmdlet.ShouldProcess("Address changes for $matchKey", "Update in PowerSchool")) {
                            if (-not $WhatIfPreference) {
                                $addressResult = Invoke-UpdateContactAddresses -ContactID $contactId -AddressChanges $addressChanges -TemplateMetadata $TemplateMetadata -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                                if (-not $addressResult.Success) {
                                    Write-Warning "Address update failed: $($addressResult.Error)"
                                }
                            }
                        }
                    }
                    
                    # Only increment success counter if not in WhatIf mode
                    if (-not $WhatIfPreference) {
                        $script:ApplyResults.UpdatedContactsApplied++
                        Write-Host "✓ $updateMessage" -ForegroundColor Cyan
                    }
                }
                catch {
                    Write-Warning "Failed to update contact $matchKey : $_"
                    $script:ApplyResults.FailedChanges.Add([PSCustomObject]@{
                        Type = 'Update'
                        MatchKey = $matchKey
                        Changes = $updatedContact.Changes
                        Error = $_.Exception.Message
                    })
                }
                
                $script:ApplyResults.ProcessedCount++
            }

            Write-Progress -Activity "Applying Contact Changes" -Completed
        }
        catch {
            Write-Error "Failed to apply contact changes: $_"
            throw
        }
    }

    end {
        # Create summary
        $summary = [PSCustomObject]@{
            TotalProcessed = $script:ApplyResults.ProcessedCount
            TotalApplied = $script:ApplyResults.NewContactsApplied + $script:ApplyResults.UpdatedContactsApplied
            TotalFailed = $script:ApplyResults.FailedChanges.Count
            LimitApplied = $Limit -lt [int]::MaxValue
        }

        # Create final result
        $result = [PSCustomObject]@{
            NewContactsApplied = $script:ApplyResults.NewContactsApplied
            UpdatedContactsApplied = $script:ApplyResults.UpdatedContactsApplied
            FailedChanges = $script:ApplyResults.FailedChanges
            Summary = $summary
        }

        # Display summary
        Write-Host "`n=== Apply Changes Summary ===" -ForegroundColor Yellow
        Write-Host "New Contacts Created: $($result.NewContactsApplied)" -ForegroundColor Green
        Write-Host "Contacts Updated: $($result.UpdatedContactsApplied)" -ForegroundColor Cyan
        Write-Host "Failed Changes: $($result.Summary.TotalFailed)" -ForegroundColor $(if ($result.Summary.TotalFailed -gt 0) { 'Red' } else { 'Gray' })
        Write-Host "Total Applied: $($result.Summary.TotalApplied) of $($result.Summary.TotalProcessed) processed"
        
        if ($result.FailedChanges.Count -gt 0) {
            Write-Warning "`nSome changes failed. Check FailedChanges property for details."
        }

        Write-Verbose "Submit-PSContactChange completed"
        
        return $result
    }
}

# Private helper function to strip table prefix from PowerSchool API field name
# Contact API field names are in format table_fieldname (e.g., person_firstname, emailaddress_emailaddress)
# but the API expects just the field name without the table prefix (e.g., firstName, emailAddress)
function Remove-TablePrefix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    # Strip table prefix (everything before and including the first underscore)
    if ($FieldName -match '^[^_]+_(.+)$') {
        return $Matches[1]
    }
    
    # No prefix found, return as-is
    return $FieldName
}

# Private helper function to build contact payload for creation
function Build-ContactPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSContact]$Contact,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata,
        
        [Parameter(Mandatory = $false)]
        [array]$EmailAddresses = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$PhoneNumbers = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$Addresses = @(),
        
        [Parameter(Mandatory = $false)]
        [array]$Relationships = @()
    )

    # Build contact object for POST /ws/contacts/contact
    # Includes demographics, emails, phones, addresses, and contactStudents (relationships)
    $payload = @{}

    # Add contact demographics fields
    foreach ($fieldName in $Contact.PSObject.Properties.Name) {
        # Get the CSV value
        $fieldValue = $Contact.$fieldName
        
        # Skip if value is null or empty
        if ([string]::IsNullOrWhiteSpace($fieldValue)) {
            continue
        }
        
        # Get the PowerSchool API field mapping for this property
        $psFieldPath = Get-PowerSchoolFieldMapping -EntityProperty $fieldName -TemplateMetadata $TemplateMetadata
        
        if ($psFieldPath) {
            # Strip table prefix (e.g., person_ from person_firstname -> firstName)
            $apiFieldName = Remove-TablePrefix -FieldName $psFieldPath
            
            # Apply the value
            $payload[$apiFieldName] = $fieldValue
        } else {
            Write-Verbose "No PowerSchool API field mapping found for property: $fieldName (skipping)"
        }
    }

    # Add emails array if provided
    if ($EmailAddresses.Count -gt 0) {
        $payload['emails'] = @($EmailAddresses | ForEach-Object {
            Build-EmailPayload -Email $_ -TemplateMetadata $TemplateMetadata
        })
        Write-Verbose "Added $($EmailAddresses.Count) email(s) to payload"
    }

    # Add phones array if provided
    if ($PhoneNumbers.Count -gt 0) {
        $payload['phones'] = @($PhoneNumbers | ForEach-Object {
            Build-PhonePayload -Phone $_ -TemplateMetadata $TemplateMetadata
        })
        Write-Verbose "Added $($PhoneNumbers.Count) phone(s) to payload"
    }

    # Add addresses array if provided
    if ($Addresses.Count -gt 0) {
        $payload['addresses'] = @($Addresses | ForEach-Object {
            Build-AddressPayload -Address $_ -TemplateMetadata $TemplateMetadata
        })
        Write-Verbose "Added $($Addresses.Count) address(es) to payload"
    }

    # Add contactStudents array (relationships) if provided
    if ($Relationships.Count -gt 0) {
        $relationshipPayloads = @($Relationships | ForEach-Object {
            Build-RelationshipPayload -Relationship $_ -TemplateMetadata $TemplateMetadata
        } | Where-Object { $null -ne $_ })
        
        if ($relationshipPayloads.Count -gt 0) {
            $payload['contactStudents'] = $relationshipPayloads
            Write-Verbose "Added $($relationshipPayloads.Count) relationship(s) to payload"
        } else {
            Write-Verbose "No valid relationships to add (all lookups failed)"
        }
    }

    return $payload
}

# Private helper function to build email payload
function Build-EmailPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSEmailAddress]$Email,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata
    )

    $emailPayload = @{
        deleted = $false
        address = $Email.EmailAddress
    }

    # Add primary status
    if ($null -ne $Email.IsPrimary) {
        $emailPayload['primary'] = [bool]$Email.IsPrimary
    }

    return $emailPayload
}

# Private helper function to build phone payload
function Build-PhonePayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSPhoneNumber]$Phone,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata
    )

    $phonePayload = @{
        deleted = $false
        phoneNumber = $Phone.PhoneNumber
    }

    # Add phone type
    if (-not [string]::IsNullOrWhiteSpace($Phone.PhoneType)) {
        $phonePayload['phoneType'] = $Phone.PhoneType
    }

    # Add sequence (priority order)
    if ($null -ne $Phone.PriorityOrder) {
        $phonePayload['sequence'] = [int]$Phone.PriorityOrder
    }

    # Add preferred status
    if ($null -ne $Phone.IsPreferred) {
        $phonePayload['preferred'] = [bool]$Phone.IsPreferred
    }

    # Add SMS capability
    if ($null -ne $Phone.IsSMS) {
        $phonePayload['sms'] = [bool]$Phone.IsSMS
    }

    return $phonePayload
}

# Private helper function to build address payload
function Build-AddressPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSAddress]$Address,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata
    )

    $addressPayload = @{
        deleted = $false
    }

    # Add address fields if available
    if (-not [string]::IsNullOrWhiteSpace($Address.Street)) {
        $addressPayload['street'] = $Address.Street
    }

    if (-not [string]::IsNullOrWhiteSpace($Address.LineTwo)) {
        $addressPayload['linetwo'] = $Address.LineTwo
    }

    if (-not [string]::IsNullOrWhiteSpace($Address.Unit)) {
        $addressPayload['unit'] = $Address.Unit
    }

    if (-not [string]::IsNullOrWhiteSpace($Address.City)) {
        $addressPayload['city'] = $Address.City
    }

    if (-not [string]::IsNullOrWhiteSpace($Address.State)) {
        $addressPayload['state'] = $Address.State
    }

    if (-not [string]::IsNullOrWhiteSpace($Address.PostalCode)) {
        $addressPayload['postalcode'] = $Address.PostalCode
    }

    # Add address type
    if (-not [string]::IsNullOrWhiteSpace($Address.AddressType)) {
        $addressPayload['addressType'] = $Address.AddressType
    }

    # Add sequence (priority order)
    if ($null -ne $Address.PriorityOrder) {
        $addressPayload['sequence'] = [int]$Address.PriorityOrder
    }

    return $addressPayload
}

# Private helper function to build relationship (contactStudent) payload
function Build-RelationshipPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSStudentContactRelationship]$Relationship,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata
    )

    # Look up student DCID from StudentNumber using PowerSchool API
    $studentDcid = $null
    try {
        Write-Verbose "Looking up DCID for student number: $($Relationship.StudentNumber)"
        $student = Get-PowerSchoolStudent -StudentNumber $Relationship.StudentNumber
        if ($student) {
            $studentDcid = $student.id
            Write-Verbose "Found student DCID: $studentDcid for student number $($Relationship.StudentNumber)"
        } else {
            Write-Warning "Could not find student with number $($Relationship.StudentNumber). Relationship will be skipped."
            return $null
        }
    }
    catch {
        Write-Warning "Failed to lookup student $($Relationship.StudentNumber): $_. Relationship will be skipped."
        return $null
    }

    $relationshipPayload = @{
        deleted = $false
        studentNumber = $Relationship.StudentNumber
        dcid = [int]$studentDcid
        studentDetails = @()
    }

    # Add sequence (contact priority order)
    if ($null -ne $Relationship.ContactPriorityOrder) {
        $relationshipPayload['sequence'] = [int]$Relationship.ContactPriorityOrder
    }

    # Build student details (relationship details)
    $studentDetail = @{
        deleted = $false
        active = $true  # PowerSchool requires exactly one detail to be active
    }

    # Add relationship type with validation
    if (-not [string]::IsNullOrWhiteSpace($Relationship.RelationshipType)) {
        # Validate relationship type using template configuration
        if ($TemplateMetadata -and $TemplateMetadata.ValidationRules -and $TemplateMetadata.ValidationRules.ValidRelationshipTypes) {
            $validRelationships = $TemplateMetadata.ValidationRules.ValidRelationshipTypes
            
            # Check if relationship type is in the allowed list
            if ($Relationship.RelationshipType -notin $validRelationships) {
                Write-Warning "Invalid relationship type '$($Relationship.RelationshipType)' for student $($Relationship.StudentNumber)."
                Write-Warning "Allowed values: $($validRelationships -join ', ')"
                Write-Warning "See docs/PowerSchool-Relationship-Codes.md for more information."
                return $null
            }
        }
        
        $studentDetail['relationship'] = $Relationship.RelationshipType
    }

    # Add relationship note
    if (-not [string]::IsNullOrWhiteSpace($Relationship.RelationshipNote)) {
        $studentDetail['relationshipNote'] = $Relationship.RelationshipNote
    }

    # Add boolean flags
    if ($null -ne $Relationship.HasCustody) {
        $studentDetail['custodial'] = [bool]$Relationship.HasCustody
    }

    if ($null -ne $Relationship.IsEmergencyContact) {
        $studentDetail['emergency'] = [bool]$Relationship.IsEmergencyContact
    }

    if ($null -ne $Relationship.LivesWith) {
        $studentDetail['livesWith'] = [bool]$Relationship.LivesWith
    }

    if ($null -ne $Relationship.AllowSchoolPickup) {
        $studentDetail['schoolPickup'] = [bool]$Relationship.AllowSchoolPickup
    }

    if ($null -ne $Relationship.ReceivesMail) {
        $studentDetail['receivesMail'] = [bool]$Relationship.ReceivesMail
    }

    # Add the student detail to the relationship
    $relationshipPayload['studentDetails'] = @($studentDetail)

    return $relationshipPayload
}

# Private helper function to build update payload from changes
function Build-ContactUpdatePayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Changes,
        
        [Parameter(Mandatory = $true)]
        [string]$ContactID,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PowerSchoolPerson,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata
    )

    # Build update object for PUT /ws/contacts/{contactId}/demographics
    # Contact demographics API expects a flat structure with just the fields being updated
    $payload = @{}

    # Map each change to PowerSchool API field
    foreach ($change in $Changes) {
        $fieldName = $change.Field
        $newValue = $change.NewValue
        
        # Get the PowerSchool API field path - prefer from change object, otherwise lookup
        $psFieldPath = if ($change.PowerSchoolAPIField) {
            $change.PowerSchoolAPIField
        } else {
            Get-PowerSchoolFieldMapping -EntityProperty $fieldName -TemplateMetadata $TemplateMetadata
        }
        
        if (-not $psFieldPath) {
            Write-Warning "No PowerSchool API field mapping found for: $fieldName"
            continue
        }

        # Strip table prefix (e.g., person_ from person_firstname -> firstName)
        $apiFieldName = Remove-TablePrefix -FieldName $psFieldPath

        # Apply the value - Contact API uses flat structure (no nested objects)
        # Handle date formatting if needed
        if ($newValue -is [DateTime]) {
            # Format dates as ISO string for PowerSchool API
            $payload[$apiFieldName] = $newValue.ToString('yyyy-MM-dd')
        } else {
            $payload[$apiFieldName] = $newValue
        }
    }

    return $payload
}

# Private helper function to invoke contact creation API
function Invoke-CreateContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )

    try {
        # Ensure connection is valid
        Test-PowerSchoolConnection

        # Get access token
        $accessToken = Get-PowerSchoolAccessToken
        
        $headers = @{
            'Authorization' = "Bearer $accessToken"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }

        $uri = "$script:PowerSchoolBaseUrl/ws/contacts/contact"

        Write-Verbose "Making API call to create contact"
        Write-Verbose "URI: POST $uri"
        Write-Verbose "Headers: Authorization=Bearer [REDACTED], Content-Type=application/json, Accept=application/json"
        Write-Verbose "Payload: $($Payload | ConvertTo-Json -Depth 10 -Compress)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Post `
            -Body $Payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds

        Write-Verbose "API call successful. Response: $($response | ConvertTo-Json -Depth 10 -Compress)"

        # Check if PowerSchool reported an error in the response
        # Contact API can return status "ERROR" even with HTTP 200
        if ($response.status -eq 'ERROR' -or $response.error_message) {
            # Parse and format the error message for better readability
            $errorDetails = @()
            
            if ($response.error_message.error) {
                foreach ($err in $response.error_message.error) {
                    $errorDetails += "Field '$($err.field)': $($err.error_description) (Code: $($err.error_code))"
                }
            }
            
            $errorMessage = if ($errorDetails.Count -gt 0) {
                "PowerSchool API validation errors:`n  " + ($errorDetails -join "`n  ")
            } else {
                "PowerSchool API error: $($response.error_message | ConvertTo-Json -Compress)"
            }
            
            # Include the full response for debugging
            Write-Verbose "Full error response: $($response | ConvertTo-Json -Depth 10)"
            
            throw $errorMessage
        }

        # Also check legacy _error_message field
        if ($response._error_message) {
            throw "PowerSchool API error: $($response._error_message)"
        }

        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        Write-Verbose "API call failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Private helper function to invoke contact update API
function Invoke-UpdateContact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContactID,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )

    try {
        # Ensure connection is valid
        Test-PowerSchoolConnection

        # Get access token
        $accessToken = Get-PowerSchoolAccessToken
        
        $headers = @{
            'Authorization' = "Bearer $accessToken"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }

        # Contact demographics update uses PUT /ws/contacts/{contactId}/demographics
        $uri = "$script:PowerSchoolBaseUrl/ws/contacts/$ContactID/demographics"

        Write-Verbose "Making API call to update contact ContactID: $ContactID"
        Write-Verbose "URI: PUT $uri"
        Write-Verbose "Headers: Authorization=Bearer [REDACTED], Content-Type=application/json, Accept=application/json"
        Write-Verbose "Payload: $($Payload | ConvertTo-Json -Depth 10 -Compress)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Put `
            -Body $Payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds

        Write-Verbose "API call successful. Response: $($response | ConvertTo-Json -Depth 10 -Compress)"

        # Check if PowerSchool reported an error in the response
        # Contact API uses _error_message, _warning_message, _success_message pattern
        if ($response._error_message) {
            throw "PowerSchool API error: $($response._error_message)"
        }

        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        Write-Verbose "API call failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}


# Private helper function to update contact emails
function Invoke-UpdateContactEmails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContactID,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$EmailChanges,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )
    
    try {
        # Build payload with all email changes
        $emailPayloads = @()
        
        # Add new emails
        foreach ($addedEmail in $EmailChanges.Added) {
            $emailPayloads += Build-EmailPayload -Email $addedEmail -TemplateMetadata $TemplateMetadata
            Write-Verbose "  Adding email: $($addedEmail.EmailAddress)"
        }
        
        # Modified emails - update with new values
        foreach ($modifiedEmail in $EmailChanges.Modified) {
            $emailPayloads += Build-EmailPayload -Email $modifiedEmail.NewEmail -TemplateMetadata $TemplateMetadata
            Write-Verbose "  Modifying email: $($modifiedEmail.OldEmail.EmailAddress) -> $($modifiedEmail.NewEmail.EmailAddress)"
        }
        
        # Removed emails - mark as deleted
        foreach ($removedEmail in $EmailChanges.Removed) {
            $deletePayload = @{
                deleted = $true
                address = $removedEmail.emailaddress_emailaddress
            }
            $emailPayloads += $deletePayload
            Write-Verbose "  Removing email: $($removedEmail.emailaddress_emailaddress)"
        }
        
        if ($emailPayloads.Count -eq 0) {
            Write-Verbose "No email changes to apply"
            return [PSCustomObject]@{ Success = $true }
        }
        
        # Make API call using PUT /ws/contacts/{contactId}
        # The Contact API requires sending the full contact object with the emails array
        $payload = @{
            emails = $emailPayloads
        }
        
        $headers = @{
            'Authorization' = "Bearer $(Get-PowerSchoolAccessToken)"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }
        
        $uri = "$script:PowerSchoolBaseUrl/ws/contacts/$ContactID"
        
        Write-Verbose "Updating emails for contact $ContactID"
        Write-Verbose "URI: PUT $uri"
        Write-Verbose "Payload: $($payload | ConvertTo-Json -Depth 10 -Compress)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Put `
            -Body $payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds
        
        Write-Verbose "Email update successful. Response: $($response | ConvertTo-Json -Depth 10 -Compress)"
        
        # Check for errors
        if ($response.status -eq 'ERROR' -or $response.error_message -or $response._error_message) {
            $errorMsg = if ($response.error_message) { $response.error_message | ConvertTo-Json -Compress } else { $response._error_message }
            throw "PowerSchool API error: $errorMsg"
        }
        
        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        Write-Verbose "Email update failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Private helper function to update contact phones
function Invoke-UpdateContactPhones {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContactID,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PhoneChanges,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )
    
    try {
        # Build payload with all phone changes
        $phonePayloads = @()
        
        # Add new phones
        foreach ($addedPhone in $PhoneChanges.Added) {
            $phonePayloads += Build-PhonePayload -Phone $addedPhone -TemplateMetadata $TemplateMetadata
            Write-Verbose "  Adding phone: $($addedPhone.PhoneNumber)"
        }
        
        # Modified phones - update with new values
        foreach ($modifiedPhone in $PhoneChanges.Modified) {
            $phonePayloads += Build-PhonePayload -Phone $modifiedPhone.NewPhone -TemplateMetadata $TemplateMetadata
            Write-Verbose "  Modifying phone: $($modifiedPhone.OldPhone.PhoneNumber) -> $($modifiedPhone.NewPhone.PhoneNumber)"
        }
        
        # Removed phones - mark as deleted
        foreach ($removedPhone in $PhoneChanges.Removed) {
            $deletePayload = @{
                deleted = $true
                phoneNumber = $removedPhone.phonenumber_phonenumber
            }
            $phonePayloads += $deletePayload
            Write-Verbose "  Removing phone: $($removedPhone.phonenumber_phonenumber)"
        }
        
        if ($phonePayloads.Count -eq 0) {
            Write-Verbose "No phone changes to apply"
            return [PSCustomObject]@{ Success = $true }
        }
        
        # Make API call using PUT /ws/contacts/{contactId}
        $payload = @{
            phones = $phonePayloads
        }
        
        $headers = @{
            'Authorization' = "Bearer $(Get-PowerSchoolAccessToken)"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }
        
        $uri = "$script:PowerSchoolBaseUrl/ws/contacts/$ContactID"
        
        Write-Verbose "Updating phones for contact $ContactID"
        Write-Verbose "URI: PUT $uri"
        Write-Verbose "Payload: $($payload | ConvertTo-Json -Depth 10 -Compress)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Put `
            -Body $payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds
        
        Write-Verbose "Phone update successful. Response: $($response | ConvertTo-Json -Depth 10 -Compress)"
        
        # Check for errors
        if ($response.status -eq 'ERROR' -or $response.error_message -or $response._error_message) {
            $errorMsg = if ($response.error_message) { $response.error_message | ConvertTo-Json -Compress } else { $response._error_message }
            throw "PowerSchool API error: $errorMsg"
        }
        
        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        Write-Verbose "Phone update failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Private helper function to update contact addresses
function Invoke-UpdateContactAddresses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContactID,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$AddressChanges,
        
        [Parameter(Mandatory = $false)]
        $TemplateMetadata,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )
    
    try {
        # Build payload with all address changes
        $addressPayloads = @()
        
        # Add new addresses
        foreach ($addedAddress in $AddressChanges.Added) {
            $addressPayloads += Build-AddressPayload -Address $addedAddress -TemplateMetadata $TemplateMetadata
            Write-Verbose "  Adding address: $($addedAddress.Street), $($addedAddress.City), $($addedAddress.State)"
        }
        
        # Modified addresses - update with new values
        foreach ($modifiedAddress in $AddressChanges.Modified) {
            $addressPayloads += Build-AddressPayload -Address $modifiedAddress.NewAddress -TemplateMetadata $TemplateMetadata
            Write-Verbose "  Modifying address: $($modifiedAddress.OldAddress.Street) -> $($modifiedAddress.NewAddress.Street)"
        }
        
        # Removed addresses - mark as deleted
        foreach ($removedAddress in $AddressChanges.Removed) {
            $deletePayload = @{
                deleted = $true
                street = $removedAddress.address_street
            }
            $addressPayloads += $deletePayload
            Write-Verbose "  Removing address: $($removedAddress.address_street)"
        }
        
        if ($addressPayloads.Count -eq 0) {
            Write-Verbose "No address changes to apply"
            return [PSCustomObject]@{ Success = $true }
        }
        
        # Make API call using PUT /ws/contacts/{contactId}
        $payload = @{
            addresses = $addressPayloads
        }
        
        $headers = @{
            'Authorization' = "Bearer $(Get-PowerSchoolAccessToken)"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }
        
        $uri = "$script:PowerSchoolBaseUrl/ws/contacts/$ContactID"
        
        Write-Verbose "Updating addresses for contact $ContactID"
        Write-Verbose "URI: PUT $uri"
        Write-Verbose "Payload: $($payload | ConvertTo-Json -Depth 10 -Compress)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Put `
            -Body $payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds
        
        Write-Verbose "Address update successful. Response: $($response | ConvertTo-Json -Depth 10 -Compress)"
        
        # Check for errors
        if ($response.status -eq 'ERROR' -or $response.error_message -or $response._error_message) {
            $errorMsg = if ($response.error_message) { $response.error_message | ConvertTo-Json -Compress } else { $response._error_message }
            throw "PowerSchool API error: $errorMsg"
        }
        
        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        Write-Verbose "Address update failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
