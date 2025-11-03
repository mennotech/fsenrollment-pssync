#Requires -Version 7.0

<#
.SYNOPSIS
    Custom parser for Final Site Enrollment parents CSV with multi-row format.

.DESCRIPTION
    Handles the complex multi-row format of the parents CSV where:
    - Contact rows contain full contact information
    - Additional phone rows contain only phone data for the same contact
    - Relationship rows link contacts to students

.PARAMETER CsvData
    Array of CSV rows to parse.

.OUTPUTS
    PSNormalizedData object containing Contacts, PhoneNumbers, EmailAddresses, Addresses, and Relationships.

.NOTES
    This is a custom parser function referenced by the fs_powerschool_nonapi_report_parents template.
#>
function Import-FSParentsCustomParser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$CsvData
    )

    try {
        # Create normalized data container
        $normalizedData = [PSNormalizedData]::new()
        
        # Track processed contacts to avoid duplicates
        $processedContacts = @{}

        # Process each row
        foreach ($row in $CsvData) {
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
        Write-Error "Failed to parse parents CSV data: $_"
        throw
    }
}
