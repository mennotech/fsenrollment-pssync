#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Compare-PSContact' {
    BeforeEach {
        # Create sample data using InModuleScope
        InModuleScope FSEnrollment-PSSync {
            $script:CsvData = [PSNormalizedData]::new()
            $script:PowerSchoolData = @()
        }
    }

    Context 'New Contacts Detection' {
        It 'Should identify new contacts not in PowerSchool' {
            InModuleScope FSEnrollment-PSSync {
                # Add contact to CSV data
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $csvContact.Gender = 'M'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool has no contacts
                $script:PowerSchoolData = @()
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.New.Count | Should -Be 1
                $result.New[0].MatchKey | Should -Be '12345'
                $result.Updated.Count | Should -Be 0
                $result.Unchanged.Count | Should -Be 0
            }
        }

        It 'Should identify multiple new contacts' {
            InModuleScope FSEnrollment-PSSync {
                # Add multiple contacts to CSV
                1..3 | ForEach-Object {
                    $contact = [PSContact]::new()
                    $contact.ContactID = "1234$_"
                    $contact.FirstName = "Contact$_"
                    $contact.LastName = "Test"
                    $script:CsvData.Contacts.Add($contact)
                }
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData @()
                
                $result.New.Count | Should -Be 3
                $result.Summary.NewCount | Should -Be 3
            }
        }
    }

    Context 'Updated Contacts Detection' {
        It 'Should identify contacts with changed first name' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'Jane'
                $csvContact.LastName = 'Doe'
                $csvContact.Gender = 'F'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person with different first name
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                    person_gender_code = 'F'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].MatchKey | Should -Be '12345'
                $result.Updated[0].Changes.Count | Should -BeGreaterThan 0
                
                # Check that FirstName is in the changes
                $firstNameChange = $result.Updated[0].Changes | Where-Object { $_.Field -eq 'FirstName' }
                $firstNameChange | Should -Not -BeNullOrEmpty
                $firstNameChange.OldValue | Should -Be 'John'
                $firstNameChange.NewValue | Should -Be 'Jane'
                $firstNameChange.PowerSchoolField | Should -Be 'person_firstname'
            }
        }

        It 'Should detect multiple field changes' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'Jane'
                $csvContact.LastName = 'Smith'
                $csvContact.Gender = 'F'
                $csvContact.Employer = 'Acme Corp'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person with different name, gender, and employer
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                    person_gender_code = 'M'
                    person_employer = 'Widget Inc'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].Changes.Count | Should -Be 4  # FirstName, LastName, Gender, Employer
                
                # Verify all expected changes are present
                $changeFields = $result.Updated[0].Changes | ForEach-Object { $_.Field }
                $changeFields | Should -Contain 'FirstName'
                $changeFields | Should -Contain 'LastName'
                $changeFields | Should -Contain 'Gender'
                $changeFields | Should -Contain 'Employer'
            }
        }

        It 'Should handle null and empty string values correctly' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with empty middle name
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.MiddleName = ''
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person with null middle name
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_middlename = $null
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                # Empty string and null should be treated as equivalent
                $result.Updated.Count | Should -Be 0
                $result.Unchanged.Count | Should -Be 1
            }
        }

        It 'Should detect change from null to value' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with employer
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $csvContact.Employer = 'Acme Corp'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person without employer
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                    person_employer = $null
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Updated.Count | Should -Be 1
                $employerChange = $result.Updated[0].Changes | Where-Object { $_.Field -eq 'Employer' }
                $employerChange | Should -Not -BeNullOrEmpty
                $employerChange.OldValue | Should -Be $null
                $employerChange.NewValue | Should -Be 'Acme Corp'
            }
        }
    }

    Context 'Unchanged Contacts Detection' {
        It 'Should identify contacts with no changes' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $csvContact.Gender = 'M'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person with matching data
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                    person_gender_code = 'M'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Unchanged.Count | Should -Be 1
                $result.Updated.Count | Should -Be 0
                $result.New.Count | Should -Be 0
            }
        }

        It 'Should handle whitespace differences as unchanged' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with extra whitespace
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = ' John '
                $csvContact.LastName = 'Doe '
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person without extra whitespace
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Unchanged.Count | Should -Be 1
                $result.Updated.Count | Should -Be 0
            }
        }
    }

    Context 'Match Field Options' {
        It 'Should match on ContactID by default' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '98765'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person with matching ID
                $psPerson = [PSCustomObject]@{
                    person_id = 98765
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Unchanged.Count | Should -Be 1
                $result.Unchanged[0].MatchField | Should -Be 'ContactID'
                $result.Summary.MatchField | Should -Be 'ContactID'
            }
        }
    }

    Context 'Summary Report' {
        It 'Should include correct counts in summary' {
            InModuleScope FSEnrollment-PSSync {
                # Add 2 new contacts
                1..2 | ForEach-Object {
                    $contact = [PSContact]::new()
                    $contact.ContactID = "new$_"
                    $contact.FirstName = "New$_"
                    $contact.LastName = "Contact"
                    $script:CsvData.Contacts.Add($contact)
                }
                
                # Add 1 updated contact
                $updatedContact = [PSContact]::new()
                $updatedContact.ContactID = '12345'
                $updatedContact.FirstName = 'Jane'
                $updatedContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($updatedContact)
                
                # Add 1 unchanged contact
                $unchangedContact = [PSContact]::new()
                $unchangedContact.ContactID = '67890'
                $unchangedContact.FirstName = 'Bob'
                $unchangedContact.LastName = 'Smith'
                $script:CsvData.Contacts.Add($unchangedContact)
                
                # PowerSchool data
                $script:PowerSchoolData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        person_firstname = 'John'  # Different from CSV
                        person_lastname = 'Doe'
                    },
                    [PSCustomObject]@{
                        person_id = 67890
                        person_firstname = 'Bob'
                        person_lastname = 'Smith'
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Summary.NewCount | Should -Be 2
                $result.Summary.UpdatedCount | Should -Be 1
                $result.Summary.UnchangedCount | Should -Be 1
                $result.Summary.TotalInCsv | Should -Be 4
                $result.Summary.TotalInPowerSchool | Should -Be 2
            }
        }

        It 'Should include match field in summary' {
            InModuleScope FSEnrollment-PSSync {
                $script:CsvData = [PSNormalizedData]::new()
                $script:PowerSchoolData = @()
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Summary.MatchField | Should -Be 'ContactID'
            }
        }
    }

    Context 'Edge Cases' {
        It 'Should handle empty CSV data' {
            InModuleScope FSEnrollment-PSSync {
                $script:CsvData = [PSNormalizedData]::new()
                $script:PowerSchoolData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        person_firstname = 'John'
                        person_lastname = 'Doe'
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.New.Count | Should -Be 0
                $result.Updated.Count | Should -Be 0
                $result.Unchanged.Count | Should -Be 0
                $result.Summary.TotalInCsv | Should -Be 0
            }
        }

        It 'Should handle empty PowerSchool data' {
            InModuleScope FSEnrollment-PSSync {
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData @()
                
                $result.New.Count | Should -Be 1
                $result.Updated.Count | Should -Be 0
                $result.Unchanged.Count | Should -Be 0
            }
        }

        It 'Should skip CSV contacts with missing match field' {
            InModuleScope FSEnrollment-PSSync {
                # Contact with valid ID
                $validContact = [PSContact]::new()
                $validContact.ContactID = '12345'
                $validContact.FirstName = 'John'
                $validContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($validContact)
                
                # Contact with empty ID
                $invalidContact = [PSContact]::new()
                $invalidContact.ContactID = ''
                $invalidContact.FirstName = 'Jane'
                $invalidContact.LastName = 'Smith'
                $script:CsvData.Contacts.Add($invalidContact)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData @() -WarningAction SilentlyContinue
                
                # Only the valid contact should be counted
                $result.New.Count | Should -Be 1
            }
        }

        It 'Should handle numeric ContactID values' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with string ID
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person with numeric ID
                $psPerson = [PSCustomObject]@{
                    person_id = 12345  # Numeric, not string
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                # Should match despite type difference
                $result.Unchanged.Count | Should -Be 1
                $result.New.Count | Should -Be 0
            }
        }
    }

    Context 'Gender Field Handling' {
        It 'Should detect gender code changes' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'Alex'
                $csvContact.LastName = 'Smith'
                $csvContact.Gender = 'F'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person with different gender
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'Alex'
                    person_lastname = 'Smith'
                    person_gender_code = 'M'
                }
                $script:PowerSchoolData = @($psPerson)
                
                $result = Compare-PSContact -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Updated.Count | Should -Be 1
                $genderChange = $result.Updated[0].Changes | Where-Object { $_.Field -eq 'Gender' }
                $genderChange | Should -Not -BeNullOrEmpty
                $genderChange.OldValue | Should -Be 'M'
                $genderChange.NewValue | Should -Be 'F'
            }
        }
    }

    Context 'Email Address Change Detection' {
        It 'Should detect new email addresses' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with email
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvEmail = [PSEmailAddress]::new()
                $csvEmail.ContactIdentifier = '12345'
                $csvEmail.EmailAddress = 'john.doe@example.com'
                $csvEmail.IsPrimary = $true
                $script:CsvData.EmailAddresses.Add($csvEmail)
                
                # PowerSchool person without email
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool email data (empty)
                $psEmailData = @()
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolEmailData $psEmailData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].EmailChanges | Should -Not -BeNullOrEmpty
                $result.Updated[0].EmailChanges.Added.Count | Should -Be 1
                $result.Updated[0].EmailChanges.Added[0].EmailAddress | Should -Be 'john.doe@example.com'
            }
        }

        It 'Should detect modified email properties' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with email marked as not primary
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvEmail = [PSEmailAddress]::new()
                $csvEmail.ContactIdentifier = '12345'
                $csvEmail.EmailAddress = 'john.doe@example.com'
                $csvEmail.IsPrimary = $false
                $script:CsvData.EmailAddresses.Add($csvEmail)
                
                # PowerSchool person
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool email data with email marked as primary
                $psEmailData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        emailaddress_emailaddress = 'john.doe@example.com'
                        emailaddress_isprimary = 1
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolEmailData $psEmailData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].EmailChanges | Should -Not -BeNullOrEmpty
                $result.Updated[0].EmailChanges.Modified.Count | Should -Be 1
            }
        }

        It 'Should detect removed email addresses' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact without email
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                # PowerSchool person
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool email data with email
                $psEmailData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        emailaddress_emailaddress = 'john.doe@example.com'
                        emailaddress_isprimary = 1
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolEmailData $psEmailData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].EmailChanges | Should -Not -BeNullOrEmpty
                $result.Updated[0].EmailChanges.Removed.Count | Should -Be 1
            }
        }
    }

    Context 'Phone Number Change Detection' {
        It 'Should detect new phone numbers' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with phone
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvPhone = [PSPhoneNumber]::new()
                $csvPhone.ContactIdentifier = '12345'
                $csvPhone.PhoneNumber = '555-123-4567'
                $csvPhone.IsPreferred = $true
                $csvPhone.IsSMS = $true
                $script:CsvData.PhoneNumbers.Add($csvPhone)
                
                # PowerSchool person without phone
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool phone data (empty)
                $psPhoneData = @()
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolPhoneData $psPhoneData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].PhoneChanges | Should -Not -BeNullOrEmpty
                $result.Updated[0].PhoneChanges.Added.Count | Should -Be 1
            }
        }

        It 'Should detect modified phone properties' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with phone marked as not SMS
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvPhone = [PSPhoneNumber]::new()
                $csvPhone.ContactIdentifier = '12345'
                $csvPhone.PhoneNumber = '(555) 123-4567'
                $csvPhone.IsPreferred = $true
                $csvPhone.IsSMS = $false
                $script:CsvData.PhoneNumbers.Add($csvPhone)
                
                # PowerSchool person
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool phone data with phone marked as SMS
                $psPhoneData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        phonenumber_phonenumber = '(555) 123-4567'
                        phonenumber_ispreferred = 1
                        phonenumber_issms = 1
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolPhoneData $psPhoneData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].PhoneChanges | Should -Not -BeNullOrEmpty
                $result.Updated[0].PhoneChanges.Modified.Count | Should -Be 1
            }
        }

        It 'Should normalize phone numbers for comparison' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with phone in one format
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvPhone = [PSPhoneNumber]::new()
                $csvPhone.ContactIdentifier = '12345'
                $csvPhone.PhoneNumber = '555-123-4567'
                $csvPhone.IsPreferred = $true
                $script:CsvData.PhoneNumbers.Add($csvPhone)
                
                # PowerSchool person
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool phone data with same number in different format
                $psPhoneData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        phonenumber_phonenumber = '(555) 123-4567'
                        phonenumber_ispreferred = 1
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolPhoneData $psPhoneData
                
                # Should be unchanged - numbers are the same despite formatting
                # Contact should be in Unchanged collection since no changes detected
                $result.Unchanged.Count | Should -Be 1
                $result.Updated.Count | Should -Be 0
            }
        }
    }

    Context 'Address Change Detection' {
        It 'Should detect new addresses' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with address
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvAddress = [PSAddress]::new()
                $csvAddress.ContactIdentifier = '12345'
                $csvAddress.Street = '123 Main St'
                $csvAddress.City = 'Springfield'
                $csvAddress.State = 'CA'
                $csvAddress.PostalCode = '12345'
                $script:CsvData.Addresses.Add($csvAddress)
                
                # PowerSchool person without address
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool address data (empty)
                $psAddressData = @()
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolAddressData $psAddressData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].AddressChanges | Should -Not -BeNullOrEmpty
                $result.Updated[0].AddressChanges.Added.Count | Should -Be 1
            }
        }

        It 'Should detect modified address fields' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with address including unit
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvAddress = [PSAddress]::new()
                $csvAddress.ContactIdentifier = '12345'
                $csvAddress.Street = '123 Main St'
                $csvAddress.LineTwo = 'Apt 4B'
                $csvAddress.City = 'Springfield'
                $csvAddress.State = 'CA'
                $csvAddress.PostalCode = '12345'
                $script:CsvData.Addresses.Add($csvAddress)
                
                # PowerSchool person
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool address data without line two
                $psAddressData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        address_street = '123 Main St'
                        address_linetwo = $null
                        address_city = 'Springfield'
                        address_state = 'CA'
                        address_postalcode = '12345'
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolAddressData $psAddressData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].AddressChanges | Should -Not -BeNullOrEmpty
                $result.Updated[0].AddressChanges.Modified.Count | Should -Be 1
            }
        }

        It 'Should match addresses by street, city, and postal code' {
            InModuleScope FSEnrollment-PSSync {
                # CSV contact with address
                $csvContact = [PSContact]::new()
                $csvContact.ContactID = '12345'
                $csvContact.FirstName = 'John'
                $csvContact.LastName = 'Doe'
                $script:CsvData.Contacts.Add($csvContact)
                
                $csvAddress = [PSAddress]::new()
                $csvAddress.ContactIdentifier = '12345'
                $csvAddress.Street = '123 Main Street'
                $csvAddress.City = 'Springfield'
                $csvAddress.State = 'CA'
                $csvAddress.PostalCode = '12345'
                $script:CsvData.Addresses.Add($csvAddress)
                
                # PowerSchool person
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'John'
                    person_lastname = 'Doe'
                }
                $script:PowerSchoolData = @($psPerson)
                
                # PowerSchool address data with matching address
                $psAddressData = @(
                    [PSCustomObject]@{
                        person_id = 12345
                        address_street = '123 Main Street'
                        address_city = 'Springfield'
                        address_state = 'CA'
                        address_postalcode = '12345'
                    }
                )
                
                $result = Compare-PSContact -CsvData $script:CsvData `
                    -PowerSchoolData $script:PowerSchoolData `
                    -PowerSchoolAddressData $psAddressData
                
                # Should be unchanged - address matches
                # Contact should be in Unchanged collection since no changes detected
                $result.Unchanged.Count | Should -Be 1
                $result.Updated.Count | Should -Be 0
            }
        }
    }
}
