#Requires -Version 7.0

<#
.SYNOPSIS
    Imports and normalizes parent/contact data from a CSV file.

.DESCRIPTION
    Parses a Final Site Enrollment parents CSV export and converts it to normalized
    PowerSchool entities (Contacts, PhoneNumbers, EmailAddresses, Addresses, and Relationships).
    
    This CSV has a complex multi-row format:
    - First row for a contact contains full contact information (name, email, address, first phone)
    - Additional rows with same ContactIdentifier but only phone data are extra phone numbers
    - Rows with a studentNumber value are relationship records linking contact to student
    
    Note: This function uses direct column mapping rather than a template configuration file
    due to the complex multi-row format that requires custom parsing logic.

.PARAMETER Path
    Path to the parents CSV file to import.

.PARAMETER TemplateName
    Reserved for future use. Currently not utilized as the function uses direct column mapping.

.OUTPUTS
    PSNormalizedData object containing Contacts, PhoneNumbers, EmailAddresses, Addresses, and Relationships.

.EXAMPLE
    $data = Import-FSParentsCsv -Path './data/parents.csv'
    
    Imports parent/contact data from the specified CSV file.

.EXAMPLE
    $data = Import-FSParentsCsv -Path './data/parents.csv'
    Write-Host "Imported $($data.Contacts.Count) contacts"
    Write-Host "Imported $($data.Relationships.Count) student-contact relationships"

.NOTES
    This function handles the complex multi-row format of the parents CSV export.
    It is designed to work cross-platform on Linux and Windows.
#>
function Import-FSParentsCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$TemplateName = 'fs_powerschool_nonapi_report_parents'
    )

    begin {
        Write-Verbose "Starting parent CSV import from: $Path"
    }

    process {
        try {
            # Import CSV file
            Write-Verbose "Importing CSV file..."
            $csvData = Import-Csv -Path $Path

            if ($null -eq $csvData -or $csvData.Count -eq 0) {
                Write-Warning "No data found in CSV file: $Path"
                return [PSNormalizedData]::new()
            }

            Write-Verbose "Found $($csvData.Count) rows in CSV"

            # Create normalized data container
            $normalizedData = [PSNormalizedData]::new()
            
            # Track processed contacts to avoid duplicates
            $processedContacts = @{}

            # Process each row
            foreach ($row in $csvData) {
                $contactId = $row.'New Contact Identifier'
                
                # Determine row type
                $isRelationshipRow = -not [string]::IsNullOrWhiteSpace($row.studentNumber)
                $hasContactInfo = -not [string]::IsNullOrWhiteSpace($row.'First Name')
                
                if ($isRelationshipRow) {
                    # This is a relationship row
                    $relationship = [PSStudentContactRelationship]::new()
                    $relationship.ContactIdentifier = $contactId
                    $relationship.StudentNumber = $row.studentNumber
                    $relationship.StudentName = $row.'* NOT MAPPED *'
                    $relationship.ContactPriorityOrder = if ($row.'Contact Priority Order') { [int]$row.'Contact Priority Order' } else { 0 }
                    $relationship.StudentContactID = $row.'Student Contact ID'
                    $relationship.StudentContactDetailID = $row.'Student Contact Detail ID'
                    $relationship.RelationshipType = $row.'Relationship Type'
                    $relationship.RelationshipNote = $row.'Relationship Note'
                    $relationship.IsLegalGuardian = $row.'STUDENTCONTACTDETAILCOREFIELDS.legalGuardian' -eq '1'
                    $relationship.HasCustody = $row.'Contact Has Custody' -eq '1'
                    $relationship.LivesWith = $row.'Contact Lives With' -eq '1'
                    $relationship.AllowSchoolPickup = $row.'Contact Allow School Pickup' -eq '1'
                    $relationship.IsEmergencyContact = $row.'Is Emergency Contact' -eq '1'
                    $relationship.ReceivesMail = $row.'Contact Receives Mailings' -eq '1'
                    
                    $normalizedData.Relationships.Add($relationship)
                    Write-Verbose "Added relationship: Contact $contactId -> Student $($row.studentNumber) as $($row.'Relationship Type')"
                }
                elseif ($hasContactInfo) {
                    # This is a new contact row
                    if (-not $processedContacts.ContainsKey($contactId)) {
                        $contact = [PSContact]::new()
                        $contact.ContactIdentifier = $contactId
                        $contact.ContactID = $row.'Contact ID'
                        $contact.Prefix = $row.Prefix
                        $contact.FirstName = $row.'First Name'
                        $contact.MiddleName = $row.'Middle Name'
                        $contact.LastName = $row.'Last Name'
                        $contact.Suffix = $row.Suffix
                        $contact.Gender = $row.Gender
                        $contact.Employer = $row.Employer
                        $contact.IsActive = $row.'Is Active' -eq '1'
                        
                        $normalizedData.Contacts.Add($contact)
                        $processedContacts[$contactId] = $true
                        Write-Verbose "Added contact: $($contact.FirstName) $($contact.LastName) ($contactId)"
                    }
                    
                    # Add email address if present
                    if (-not [string]::IsNullOrWhiteSpace($row.'Email Address')) {
                        $email = [PSEmailAddress]::new()
                        $email.ContactIdentifier = $contactId
                        $email.EmailAddress = $row.'Email Address'
                        $email.EmailAddressID = $row.'Contact Email Address ID'
                        $email.IsPrimary = $row.'Is Primary Email Address' -eq '1'
                        
                        $normalizedData.EmailAddresses.Add($email)
                        Write-Verbose "Added email for $contactId : $($email.EmailAddress)"
                    }
                    
                    # Add address if present
                    if (-not [string]::IsNullOrWhiteSpace($row.Street)) {
                        $address = [PSAddress]::new()
                        $address.ContactIdentifier = $contactId
                        $address.AddressType = $row.'Address Type'
                        $address.Street = $row.Street
                        $address.LineTwo = $row.'Line Two'
                        $address.Unit = $row.Unit
                        $address.City = $row.City
                        $address.State = $row.State
                        $address.PostalCode = $row.'Postal Code'
                        $address.AddressID = $row.'Contact Address ID'
                        $address.PriorityOrder = if ($row.'Address Priority Order') { [int]$row.'Address Priority Order' } else { 0 }
                        
                        $normalizedData.Addresses.Add($address)
                        Write-Verbose "Added address for $contactId : $($address.City), $($address.State)"
                    }
                    
                    # Add phone number if present
                    if (-not [string]::IsNullOrWhiteSpace($row.phoneNumberAsEntered)) {
                        $phone = [PSPhoneNumber]::new()
                        $phone.ContactIdentifier = $contactId
                        $phone.PriorityOrder = if ($row.'Phone Number Priority Order') { [int]$row.'Phone Number Priority Order' } else { 0 }
                        $phone.PhoneType = $row.'Phone Type'
                        $phone.PhoneNumber = $row.phoneNumberAsEntered
                        $phone.IsPreferred = $row.'Is Preferred' -eq '1'
                        $phone.IsSMS = $row.'Is SMS' -eq '1'
                        $phone.PhoneNumberID = $row.'Contact Phone Number ID'
                        
                        $normalizedData.PhoneNumbers.Add($phone)
                        Write-Verbose "Added phone for $contactId : $($phone.PhoneType) - $($phone.PhoneNumber)"
                    }
                }
                else {
                    # This is an additional phone number row (no contact info, just phone data)
                    if (-not [string]::IsNullOrWhiteSpace($row.phoneNumberAsEntered)) {
                        $phone = [PSPhoneNumber]::new()
                        $phone.ContactIdentifier = $contactId
                        $phone.PriorityOrder = if ($row.'Phone Number Priority Order') { [int]$row.'Phone Number Priority Order' } else { 0 }
                        $phone.PhoneType = $row.'Phone Type'
                        $phone.PhoneNumber = $row.phoneNumberAsEntered
                        $phone.IsPreferred = $row.'Is Preferred' -eq '1'
                        $phone.IsSMS = $row.'Is SMS' -eq '1'
                        $phone.PhoneNumberID = $row.'Contact Phone Number ID'
                        
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
            Write-Error "Failed to import parents CSV: $_"
            throw
        }
    }

    end {
        Write-Verbose "Parent CSV import completed"
    }
}
