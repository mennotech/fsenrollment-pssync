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

        # Get column mappings for each entity type
        $contactMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.Contact) { $TemplateConfig.ColumnMappings.Contact } else { @() }
        $emailMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.EmailAddress) { $TemplateConfig.ColumnMappings.EmailAddress } else { @() }
        $phoneMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.PhoneNumber) { $TemplateConfig.ColumnMappings.PhoneNumber } else { @() }
        $addressMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.Address) { $TemplateConfig.ColumnMappings.Address } else { @() }
        $relationshipMappings = if ($TemplateConfig -and $TemplateConfig.ColumnMappings.Relationship) { $TemplateConfig.ColumnMappings.Relationship } else { @() }

        # Helper function to apply mappings to an entity
        function Apply-ColumnMappings {
            param($Row, $Entity, $Mappings)
            
            foreach ($mapping in $Mappings) {
                $csvColumn = $mapping.CSVColumn
                $entityProperty = $mapping.EntityProperty
                $dataType = $mapping.DataType
                
                # Get the value from CSV row
                $value = $Row.$csvColumn
                
                # Skip if value is null or empty string
                if ([string]::IsNullOrWhiteSpace($value)) {
                    continue
                }
                
                # Convert to appropriate data type
                $convertedValue = switch ($dataType) {
                    'int' {
                        try {
                            [int]$value
                        }
                        catch {
                            Write-Warning "Failed to convert '$value' to int for property $entityProperty"
                            0
                        }
                    }
                    'bool' {
                        if ($value -eq '1' -or $value -eq 'true' -or $value -eq 'True') {
                            $true
                        }
                        elseif ($value -eq '0' -or $value -eq 'false' -or $value -eq 'False') {
                            $false
                        }
                        else {
                            Write-Warning "Unexpected boolean value '$value' for property $entityProperty. Expected '0', '1', 'true', or 'false'. Attempting standard conversion."
                            [bool]$value
                        }
                    }
                    'datetime' {
                        try {
                            [datetime]::Parse($value)
                        }
                        catch {
                            Write-Warning "Failed to convert '$value' to datetime for property $entityProperty"
                            $null
                        }
                    }
                    default {
                        # Default to string
                        [string]$value
                    }
                }
                
                # Set the property value
                if ($null -ne $convertedValue -or $dataType -eq 'bool') {
                    $Entity.$entityProperty = $convertedValue
                }
            }
        }

        # Process each row
        foreach ($row in $CsvData) {
            $contactId = $row.'New Contact Identifier'
            
            # Determine row type
            $isRelationshipRow = -not [string]::IsNullOrWhiteSpace($row.studentNumber)
            $hasContactInfo = -not [string]::IsNullOrWhiteSpace($row.'First Name')
            
            if ($isRelationshipRow) {
                # This is a relationship row
                $relationship = [PSStudentContactRelationship]::new()
                Apply-ColumnMappings -Row $row -Entity $relationship -Mappings $relationshipMappings
                
                $normalizedData.Relationships.Add($relationship)
                Write-Verbose "Added relationship: Contact $contactId -> Student $($row.studentNumber) as $($row.'Relationship Type')"
            }
            elseif ($hasContactInfo) {
                # This is a new contact row
                if (-not $processedContacts.ContainsKey($contactId)) {
                    $contact = [PSContact]::new()
                    Apply-ColumnMappings -Row $row -Entity $contact -Mappings $contactMappings
                    
                    $normalizedData.Contacts.Add($contact)
                    $processedContacts[$contactId] = $true
                    Write-Verbose "Added contact: $($contact.FirstName) $($contact.LastName) ($contactId)"
                }
                
                # Add email address if present
                if (-not [string]::IsNullOrWhiteSpace($row.'Email Address')) {
                    $email = [PSEmailAddress]::new()
                    Apply-ColumnMappings -Row $row -Entity $email -Mappings $emailMappings
                    
                    $normalizedData.EmailAddresses.Add($email)
                    Write-Verbose "Added email for $contactId : $($email.EmailAddress)"
                }
                
                # Add address if present
                if (-not [string]::IsNullOrWhiteSpace($row.Street)) {
                    $address = [PSAddress]::new()
                    Apply-ColumnMappings -Row $row -Entity $address -Mappings $addressMappings
                    
                    $normalizedData.Addresses.Add($address)
                    Write-Verbose "Added address for $contactId : $($address.City), $($address.State)"
                }
                
                # Add phone number if present
                if (-not [string]::IsNullOrWhiteSpace($row.phoneNumberAsEntered)) {
                    $phone = [PSPhoneNumber]::new()
                    Apply-ColumnMappings -Row $row -Entity $phone -Mappings $phoneMappings
                    
                    $normalizedData.PhoneNumbers.Add($phone)
                    Write-Verbose "Added phone for $contactId : $($phone.PhoneType) - $($phone.PhoneNumber)"
                }
            }
            else {
                # This is an additional phone number row (no contact info, just phone data)
                if (-not [string]::IsNullOrWhiteSpace($row.phoneNumberAsEntered)) {
                    $phone = [PSPhoneNumber]::new()
                    Apply-ColumnMappings -Row $row -Entity $phone -Mappings $phoneMappings
                    
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
