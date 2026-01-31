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
    
    Phase 1: This function only applies contact demographic changes (firstName, lastName, 
    middleName, prefix, suffix, gender, employer). Email addresses, phone numbers, addresses, 
    and relationships will be added in Phase 2.

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
    Phase 1: Only applies changes to contact demographic fields (firstName, lastName, middleName, prefix, suffix, gender, employer).
    TemplateMetadata is required and must be included in the Changes object from Compare-PSContact.
    All field mappings are driven by the template configuration - no hardcoded mappings exist.
    
    API Endpoints:
    - POST /ws/contacts/contact - Create new contact
    - PUT /ws/contacts/contact/{contactId}/demographics - Update contact demographics
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
            
            # Convert TemplateMetadata from PSCustomObject to Hashtable if needed (happens when loading from JSON)
            if ($Changes.TemplateMetadata -is [PSCustomObject]) {
                $TemplateMetadata = @{}
                foreach ($property in $Changes.TemplateMetadata.PSObject.Properties) {
                    if ($property.Value -is [Array]) {
                        # Convert array items if they're PSCustomObjects
                        $TemplateMetadata[$property.Name] = @($property.Value | ForEach-Object {
                            if ($_ -is [PSCustomObject]) {
                                $ht = @{}
                                foreach ($prop in $_.PSObject.Properties) {
                                    $ht[$prop.Name] = $prop.Value
                                }
                                $ht
                            } else {
                                $_
                            }
                        })
                    } else {
                        $TemplateMetadata[$property.Name] = $property.Value
                    }
                }
            } else {
                $TemplateMetadata = $Changes.TemplateMetadata
            }
            Write-Verbose "Using TemplateMetadata from Changes object (Template: $($TemplateMetadata.TemplateName))"

            # Calculate total changes to apply
            $totalChanges = $Changes.New.Count + $Changes.Updated.Count
            $changesToApply = [Math]::Min($totalChanges, $Limit)
            
            Write-Verbose "Total changes available: $totalChanges (New: $($Changes.New.Count), Updated: $($Changes.Updated.Count))"
            Write-Verbose "Changes to apply (with limit): $changesToApply"

            if ($WhatIfPreference) {
                Write-Host "WhatIf: Would apply $changesToApply of $totalChanges changes" -ForegroundColor Yellow
            }

            $changeNumber = 0

            # Process new contacts
            foreach ($newContact in $Changes.New) {
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
                    
                    # Build contact payload for API (always build for detailed display)
                    $payload = Build-ContactPayload -Contact $contact -TemplateMetadata $TemplateMetadata
                    
                    if ($WhatIfPreference) {
                        Write-Host "`n=== WHATIF: New Contact Creation ===" -ForegroundColor Cyan
                        Write-Host "Contact: $matchKey ($($contact.FirstName) $($contact.LastName))" -ForegroundColor Yellow
                        Write-Verbose "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/contacts/contact"
                        
                        # Show field details for new contact - iterate dynamically
                        Write-Host "Contact Fields to Create:" -ForegroundColor Gray
                        $contactData = $payload.contact
                        
                        # Display contact fields
                        foreach ($key in ($contactData.Keys | Where-Object { $_ -notin @('action') } | Sort-Object)) {
                            $value = $contactData[$key]
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
                            $contactData = $payload.contact
                            
                            # Display contact fields
                            foreach ($key in ($contactData.Keys | Where-Object { $_ -notin @('action') } | Sort-Object)) {
                                $value = $contactData[$key]
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
                if ($changeNumber -ge $Limit) {
                    Write-Verbose "Reached limit of $Limit changes, stopping"
                    break
                }
                
                $changeNumber++
                Write-Progress -Activity "Applying Contact Changes" `
                    -Status "Processing updated contact $changeNumber of $changesToApply" `
                    -PercentComplete (($changeNumber / $changesToApply) * 100)

                try {
                    $matchKey = $updatedContact.MatchKey
                    $changes = $updatedContact.Changes
                    # Handle both single change object and array of changes
                    if ($changes -and -not ($changes -is [array])) {
                        $changes = @($changes)
                    }
                    $psPerson = $updatedContact.PowerSchoolPerson
                    
                    # Get contact person_id (ContactID) for update
                    $contactId = $psPerson.person_id
                    if (-not $contactId) {
                        throw "PowerSchool contact person_id (ContactID) not found for $matchKey"
                    }
                    
                    # Build update payload (always build for detailed display)
                    $payload = Build-ContactUpdatePayload -Changes $changes -ContactID $contactId -PowerSchoolPerson $psPerson -TemplateMetadata $TemplateMetadata
                    
                    # Build readable update message
                    $contactName = "$($psPerson.person_firstname) $($psPerson.person_middlename) $($psPerson.person_lastname)".Trim()
                    $changedFields = $changes.Field -join ', '
                    $updateMessage = "Contact: $matchKey (ContactID: $contactId) Name: $contactName - $($changes.Count) changes Fields: $changedFields"
                    if ($WhatIfPreference) {
                        Write-Verbose "API Endpoint: PUT $($script:PowerSchoolBaseUrl)/ws/contacts/contact/$contactId/demographics"
                        Write-Verbose "Field Changes ($($changes.Count) total):"
                        foreach ($change in $changes) {
                            Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                            # Use the PowerSchoolAPIField from the change item if available, otherwise look it up
                            $mappingDesc = if ($change.PowerSchoolAPIField) {
                                $change.PowerSchoolAPIField
                            } else {
                                Get-PowerSchoolFieldMapping -EntityProperty $change.Field -TemplateMetadata $TemplateMetadata
                            }
                            if ($mappingDesc) {
                                Write-Verbose "    (API Field: $mappingDesc)"
                            }
                        }
                        
                        # Only show full payload with -Verbose
                        Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10)"
                    }
                    
                    if ($PSCmdlet.ShouldProcess($updateMessage, "Update in PowerSchool")) {
                        if (-not $WhatIfPreference) {
                            Write-Verbose "Updating contact: $matchKey (ContactID: $contactId) with $($changes.Count) changes"
                            Write-Verbose "API Endpoint: PUT $($script:PowerSchoolBaseUrl)/ws/contacts/contact/$contactId/demographics"
                            Write-Verbose "Changes being applied:"
                            foreach ($change in $changes) {
                                Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                                # Use the PowerSchoolAPIField from the change item if available, otherwise look it up
                                $mappingDesc = if ($change.PowerSchoolAPIField) {
                                    $change.PowerSchoolAPIField
                                } else {
                                    Get-PowerSchoolFieldMapping -EntityProperty $change.Field -TemplateMetadata $TemplateMetadata
                                }
                                if ($mappingDesc) {
                                    Write-Verbose "    API Field: $mappingDesc"
                                }
                            }
                            Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10 -Compress)"
                            
                            # Make API call to update contact
                            $result = Invoke-UpdateContact -ContactID $contactId -Payload $payload -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                            
                            if ($result.Success) {
                                $script:ApplyResults.UpdatedContactsApplied++
                                Write-Host "✓ $updateMessage" -ForegroundColor Cyan
                                foreach ($change in $changes) {
                                    Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                                }
                                Write-Verbose "Successfully updated contact with API response: $($result.Response | ConvertTo-Json -Depth 10 -Compress)"
                            } else {
                                throw $result.Error
                            }
                        }
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

# Private helper function to build contact payload for creation
function Build-ContactPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSContact]$Contact,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateMetadata
    )

    # Build basic contact object for POST /ws/contacts/contact
    # Contact API uses flat structure (no nested objects like student API)
    $payload = @{
        contact = @{
            action = "INSERT"
        }
    }

    $contactData = $payload.contact

    # Phase 1: Demographics fields only (firstName, lastName, middleName, prefix, suffix, gender, employer)
    # Map PSContact properties to PowerSchool Contact API fields
    $demographicFields = @('FirstName', 'MiddleName', 'LastName', 'Prefix', 'Suffix', 'Gender', 'Employer')
    
    foreach ($fieldName in $demographicFields) {
        # Get the CSV value
        $fieldValue = $Contact.$fieldName
        
        # Skip if value is null or empty
        if ([string]::IsNullOrWhiteSpace($fieldValue)) {
            continue
        }
        
        # Get the PowerSchool API field mapping for this property
        $psFieldPath = Get-PowerSchoolFieldMapping -EntityProperty $fieldName -TemplateMetadata $TemplateMetadata
        
        if ($psFieldPath) {
            # Apply the value - Contact API uses flat structure
            $contactData[$psFieldPath] = $fieldValue
        } else {
            Write-Verbose "No PowerSchool API field mapping found for property: $fieldName (skipping)"
        }
    }

    return $payload
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
        [hashtable]$TemplateMetadata
    )

    # Build update object for PUT /ws/contacts/contact/{contactId}/demographics
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

        # Apply the value - Contact API uses flat structure (no nested objects)
        # Handle date formatting if needed
        if ($newValue -is [DateTime]) {
            # Format dates as ISO string for PowerSchool API
            $payload[$psFieldPath] = $newValue.ToString('yyyy-MM-dd')
        } else {
            $payload[$psFieldPath] = $newValue
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

        # Contact demographics update uses PUT /ws/contacts/contact/{contactId}/demographics
        $uri = "$script:PowerSchoolBaseUrl/ws/contacts/contact/$ContactID/demographics"

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
