#Requires -Version 7.0

<#
.SYNOPSIS
    Custom parser for Final Site Enrollment parents CSV with multi-row format.

.DESCRIPTION
    Handles the complex multi-row format of the parents CSV where:
    - Contact rows contain full contact information
    - Additional phone rows contain only phone data for the same contact
    - Relationship rows link contacts to students
    
    Uses column mappings from the template configuration to map CSV fields to entity properties.
    Utilizes the Invoke-ColumnMapping private function for field conversion.

.PARAMETER CsvData
    Array of CSV rows to parse.

.PARAMETER TemplateConfig
    Template configuration hashtable containing column mappings for each entity type.

.OUTPUTS
    PSNormalizedData object containing Contacts, PhoneNumbers, EmailAddresses, Addresses, and Relationships.

.NOTES
    This is a custom parser function referenced by the fs_powerschool_nonapi_report_parents template.
#>
function Import-FSParentsCustomParser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$CsvData,

        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateConfig
    )

    try {
        # Create normalized data container
        $normalizedData = [PSNormalizedData]::new()
        
        # Track processed contacts to avoid duplicates
        $processedContacts = @{}
        
        # Track excluded contacts (by ContactIdentifier)
        $excludedContacts = @{}

        # Get column mappings for each entity type
        $contactMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.Contact) { $TemplateConfig.ColumnMappings.Contact } else { @() }
        $emailMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.EmailAddress) { $TemplateConfig.ColumnMappings.EmailAddress } else { @() }
        $phoneMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.PhoneNumber) { $TemplateConfig.ColumnMappings.PhoneNumber } else { @() }
        $addressMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.Address) { $TemplateConfig.ColumnMappings.Address } else { @() }
        $relationshipMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.Relationship) { $TemplateConfig.ColumnMappings.Relationship } else { @() }

        # Get the exclude column name from template configuration (optional)
        $excludeColumnName = if ($TemplateConfig -and $TemplateConfig.ExcludeColumnName) { 
            $TemplateConfig.ExcludeColumnName 
        } else { 
            $null 
        }

        # Get the datetime format from template configuration (optional)
        $dateTimeFormat = if ($TemplateConfig -and $TemplateConfig.DateTimeFormat) {
            $TemplateConfig.DateTimeFormat
        } else {
            $null
        }

        # First pass: identify excluded contacts (only if exclude column is configured and exists in CSV)
        if ($excludeColumnName -and $CsvData.Count -gt 0) {
            # Check if the exclude column exists in the CSV
            $firstRow = $CsvData[0]
            $columnExists = $firstRow.PSObject.Properties.Name -contains $excludeColumnName
            
            if ($columnExists) {
                Write-Verbose "Exclude column '$excludeColumnName' found in CSV, checking for excluded contacts"
                
                foreach ($row in $CsvData) {
                    $contactId = $row.'New Contact Identifier'
                    $hasContactInfo = -not [string]::IsNullOrWhiteSpace($row.'First Name')
                    
                    # Only check exclude flag on contact info rows
                    if ($hasContactInfo) {
                        $excludeValue = $row.$excludeColumnName
                        if (-not [string]::IsNullOrWhiteSpace($excludeValue)) {
                            $excludeValueStr = $excludeValue.ToString().Trim()
                            $excludeFromExport = $excludeValueStr -in @('true', 'True', 'TRUE', '1', 'yes', 'Yes', 'YES')
                            
                            if ($excludeFromExport) {
                                $excludedContacts[$contactId] = $true
                                Write-Verbose "Marking contact for exclusion: $contactId ($($row.'First Name') $($row.'Last Name'))"
                            }
                        }
                    }
                }
            }
            else {
                Write-Verbose "Exclude column '$excludeColumnName' not found in CSV, proceeding without exclusions"
            }
        }

        # Second pass: process rows, skipping excluded contacts
        foreach ($row in $CsvData) {
            $contactId = $row.'New Contact Identifier'
            
            # Skip all rows for excluded contacts
            if ($excludedContacts.ContainsKey($contactId)) {
                continue
            }
            
            # Determine row type
            $isRelationshipRow = -not [string]::IsNullOrWhiteSpace($row.studentNumber)
            $hasContactInfo = -not [string]::IsNullOrWhiteSpace($row.'First Name')
            
            if ($isRelationshipRow) {
                # This is a relationship row
                $relationship = [PSStudentContactRelationship]::new()
                Invoke-ColumnMapping -CsvRow $row -Entity $relationship -ColumnMappings $relationshipMappings -DateTimeFormat $dateTimeFormat
                
                $normalizedData.Relationships.Add($relationship)
                Write-Verbose "Added relationship: Contact $contactId -> Student $($row.studentNumber) as $($row.'Relationship Type')"
            }
            elseif ($hasContactInfo) {
                # This is a new contact row
                if (-not $processedContacts.ContainsKey($contactId)) {
                    $contact = [PSContact]::new()
                    Invoke-ColumnMapping -CsvRow $row -Entity $contact -ColumnMappings $contactMappings -DateTimeFormat $dateTimeFormat
                    
                    $normalizedData.Contacts.Add($contact)
                    $processedContacts[$contactId] = $true
                    Write-Verbose "Added contact: $($contact.FirstName) $($contact.LastName) ($contactId)"
                }
                
                # Add email address if present
                if (-not [string]::IsNullOrWhiteSpace($row.'Email Address')) {
                    $email = [PSEmailAddress]::new()
                    Invoke-ColumnMapping -CsvRow $row -Entity $email -ColumnMappings $emailMappings -DateTimeFormat $dateTimeFormat
                    
                    $normalizedData.EmailAddresses.Add($email)
                    Write-Verbose "Added email for $contactId : $($email.EmailAddress)"
                }
                
                # Add address if present
                if (-not [string]::IsNullOrWhiteSpace($row.Street)) {
                    $address = [PSAddress]::new()
                    Invoke-ColumnMapping -CsvRow $row -Entity $address -ColumnMappings $addressMappings -DateTimeFormat $dateTimeFormat
                    
                    $normalizedData.Addresses.Add($address)
                    Write-Verbose "Added address for $contactId : $($address.City), $($address.State)"
                }
                
                # Add phone number if present
                if (-not [string]::IsNullOrWhiteSpace($row.phoneNumberAsEntered)) {
                    $phone = [PSPhoneNumber]::new()
                    Invoke-ColumnMapping -CsvRow $row -Entity $phone -ColumnMappings $phoneMappings -DateTimeFormat $dateTimeFormat
                    
                    $normalizedData.PhoneNumbers.Add($phone)
                    Write-Verbose "Added phone for $contactId : $($phone.PhoneType) - $($phone.PhoneNumber)"
                }
            }
            else {
                # This is an additional phone number row (no contact info, just phone data)
                if (-not [string]::IsNullOrWhiteSpace($row.phoneNumberAsEntered)) {
                    $phone = [PSPhoneNumber]::new()
                    Invoke-ColumnMapping -CsvRow $row -Entity $phone -ColumnMappings $phoneMappings -DateTimeFormat $dateTimeFormat
                    
                    $normalizedData.PhoneNumbers.Add($phone)
                    Write-Verbose "Added additional phone for $contactId : $($phone.PhoneType) - $($phone.PhoneNumber)"
                }
            }
        }

        Write-Verbose "Successfully imported:"
        Write-Verbose "  - $($normalizedData.Contacts.Count) contacts"
        Write-Verbose "  - $($normalizedData.EmailAddresses.Count) email addresses"
        Write-Verbose "  - $($normalizedData.PhoneNumbers.Count) phone numbers"
        Write-Verbose "  - $($normalizedData.Addresses.Count) addresses"
        Write-Verbose "  - $($normalizedData.Relationships.Count) student-contact relationships"
        
        return $normalizedData
    }
    catch {
        Write-Error "Failed to parse parents CSV data: $_"
        throw
    }
}
