#Requires -Version 7.0

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $PublicPath = Join-Path $ModuleRoot 'public'
    
    . (Join-Path $PublicPath 'Get-CsvNormalizationTemplate.ps1')
    . (Join-Path $PublicPath 'ConvertTo-ParentStudentRelationships.ps1')
}

Describe 'ConvertTo-ParentStudentRelationships' {
    BeforeAll {
        # Create test data that mimics the Final Site Enrollment parent CSV structure
        $testParentData = @(
            # Parent 1 - demographic row with phone
            [PSCustomObject]@{
                'New Contact Identifier' = 'contact-001'
                'Contact ID' = ''
                'Prefix' = 'Mr.'
                'First Name' = 'John'
                'Middle Name' = ''
                'Last Name' = 'Smith'
                'Suffix' = ''
                'Gender' = 'M'
                'Employer' = 'Acme Corp'
                'Is Active' = '1'
                'Email Address' = 'john.smith@example.com'
                'Phone Type' = 'Mobile'
                'phoneNumberAsEntered' = '555-1234'
                'Is Preferred' = '1'
                'Is SMS' = ''
                'Address Type' = 'Home'
                'Street' = '123 Main St'
                'Line Two' = ''
                'Unit' = ''
                'City' = 'Toronto'
                'State' = 'ON'
                'Postal Code' = 'M1A 1A1'
                'studentNumber' = ''
                'Relationship Type' = ''
            }
            # Parent 1 - additional phone
            [PSCustomObject]@{
                'New Contact Identifier' = 'contact-001'
                'Contact ID' = ''
                'Prefix' = ''
                'First Name' = ''
                'Middle Name' = ''
                'Last Name' = ''
                'Suffix' = ''
                'Gender' = ''
                'Employer' = ''
                'Is Active' = ''
                'Email Address' = ''
                'Phone Type' = 'Home'
                'phoneNumberAsEntered' = '555-5678'
                'Is Preferred' = '1'
                'Is SMS' = ''
                'Address Type' = ''
                'Street' = ''
                'Line Two' = ''
                'Unit' = ''
                'City' = ''
                'State' = ''
                'Postal Code' = ''
                'studentNumber' = ''
                'Relationship Type' = ''
            }
            # Parent 1 - relationship 1
            [PSCustomObject]@{
                'New Contact Identifier' = 'contact-001'
                'Contact ID' = ''
                'Prefix' = ''
                'First Name' = ''
                'Middle Name' = ''
                'Last Name' = ''
                'Suffix' = ''
                'Gender' = ''
                'Employer' = ''
                'Is Active' = ''
                'Email Address' = ''
                'Phone Type' = ''
                'phoneNumberAsEntered' = ''
                'Is Preferred' = ''
                'Is SMS' = ''
                'Address Type' = ''
                'Street' = ''
                'Line Two' = ''
                'Unit' = ''
                'City' = ''
                'State' = ''
                'Postal Code' = ''
                'studentNumber' = '12345'
                'Relationship Type' = 'Father'
                'STUDENTCONTACTDETAILCOREFIELDS.legalGuardian' = '1'
                'Contact Has Custody' = '1'
                'Contact Lives With' = '1'
                'Contact Allow School Pickup' = '1'
                'Is Emergency Contact' = '1'
                'Contact Receives Mailings' = '1'
                'Contact Priority Order' = '1'
            }
            # Parent 1 - relationship 2
            [PSCustomObject]@{
                'New Contact Identifier' = 'contact-001'
                'Contact ID' = ''
                'Prefix' = ''
                'First Name' = ''
                'Middle Name' = ''
                'Last Name' = ''
                'Suffix' = ''
                'Gender' = ''
                'Employer' = ''
                'Is Active' = ''
                'Email Address' = ''
                'Phone Type' = ''
                'phoneNumberAsEntered' = ''
                'Is Preferred' = ''
                'Is SMS' = ''
                'Address Type' = ''
                'Street' = ''
                'Line Two' = ''
                'Unit' = ''
                'City' = ''
                'State' = ''
                'Postal Code' = ''
                'studentNumber' = '67890'
                'Relationship Type' = 'Father'
                'STUDENTCONTACTDETAILCOREFIELDS.legalGuardian' = '1'
                'Contact Has Custody' = '1'
                'Contact Lives With' = '1'
                'Contact Allow School Pickup' = '1'
                'Is Emergency Contact' = '1'
                'Contact Receives Mailings' = '1'
                'Contact Priority Order' = '1'
            }
            # Parent 2 - demographic row
            [PSCustomObject]@{
                'New Contact Identifier' = 'contact-002'
                'Contact ID' = ''
                'Prefix' = 'Mrs.'
                'First Name' = 'Jane'
                'Middle Name' = 'A'
                'Last Name' = 'Doe'
                'Suffix' = ''
                'Gender' = 'F'
                'Employer' = 'Self Employed'
                'Is Active' = '1'
                'Email Address' = 'jane.doe@example.com'
                'Phone Type' = 'Mobile'
                'phoneNumberAsEntered' = '555-9999'
                'Is Preferred' = '1'
                'Is SMS' = '1'
                'Address Type' = 'Home'
                'Street' = '456 Oak Ave'
                'Line Two' = 'Apt 2B'
                'Unit' = ''
                'City' = 'Vancouver'
                'State' = 'BC'
                'Postal Code' = 'V1A 1A1'
                'studentNumber' = ''
                'Relationship Type' = ''
            }
            # Parent 2 - relationship
            [PSCustomObject]@{
                'New Contact Identifier' = 'contact-002'
                'Contact ID' = ''
                'Prefix' = ''
                'First Name' = ''
                'Middle Name' = ''
                'Last Name' = ''
                'Suffix' = ''
                'Gender' = ''
                'Employer' = ''
                'Is Active' = ''
                'Email Address' = ''
                'Phone Type' = ''
                'phoneNumberAsEntered' = ''
                'Is Preferred' = ''
                'Is SMS' = ''
                'Address Type' = ''
                'Street' = ''
                'Line Two' = ''
                'Unit' = ''
                'City' = ''
                'State' = ''
                'Postal Code' = ''
                'studentNumber' = '12345'
                'Relationship Type' = 'Mother'
                'STUDENTCONTACTDETAILCOREFIELDS.legalGuardian' = '1'
                'Contact Has Custody' = '1'
                'Contact Lives With' = '1'
                'Contact Allow School Pickup' = '1'
                'Is Emergency Contact' = '1'
                'Contact Receives Mailings' = '1'
                'Contact Priority Order' = '2'
            }
        )
    }

    Context 'When processing parent CSV data' {
        It 'Should return an object with Contacts, PhoneNumbers, and Relationships properties' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'Contacts'
            $result.PSObject.Properties.Name | Should -Contain 'PhoneNumbers'
            $result.PSObject.Properties.Name | Should -Contain 'Relationships'
        }

        It 'Should extract the correct number of contacts' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $result.Contacts.Count | Should -Be 2
        }

        It 'Should extract the correct number of phone numbers' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            # 2 phones for contact-001, 1 phone for contact-002
            $result.PhoneNumbers.Count | Should -Be 3
        }

        It 'Should extract the correct number of relationships' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            # 2 relationships for contact-001, 1 relationship for contact-002
            $result.Relationships.Count | Should -Be 3
        }
    }

    Context 'When processing contact demographic data' {
        It 'Should map contact fields correctly' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $contact = $result.Contacts | Where-Object { $_.id -eq 'contact-001' }
            
            $contact.id | Should -Be 'contact-001'
            $contact.prefix | Should -Be 'Mr.'
            $contact.first_name | Should -Be 'John'
            $contact.last_name | Should -Be 'Smith'
            $contact.gender | Should -Be 'M'
            $contact.employer | Should -Be 'Acme Corp'
            $contact.email | Should -Be 'john.smith@example.com'
        }

        It 'Should convert is_active to boolean' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $contact = $result.Contacts[0]
            $contact.is_active | Should -Be $true
            $contact.is_active | Should -BeOfType [bool]
        }

        It 'Should map address fields correctly' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $contact = $result.Contacts | Where-Object { $_.id -eq 'contact-001' }
            
            $contact.street | Should -Be '123 Main St'
            $contact.city | Should -Be 'Toronto'
            $contact.state | Should -Be 'ON'
            $contact.postal_code | Should -Be 'M1A 1A1'
        }
    }

    Context 'When processing phone number data' {
        It 'Should link phone numbers to correct contact' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $phones = $result.PhoneNumbers | Where-Object { $_.contact_id -eq 'contact-001' }
            $phones.Count | Should -Be 2
        }

        It 'Should map phone fields correctly' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $phone = $result.PhoneNumbers | Where-Object { $_.contact_id -eq 'contact-001' -and $_.phone_type -eq 'Mobile' }
            
            $phone.phone_type | Should -Be 'Mobile'
            $phone.phone_number | Should -Be '555-1234'
        }

        It 'Should convert is_preferred_phone to boolean' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $phone = $result.PhoneNumbers[0]
            $phone.is_preferred_phone | Should -Be $true
            $phone.is_preferred_phone | Should -BeOfType [bool]
        }

        It 'Should handle multiple phone numbers per contact' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $phones = $result.PhoneNumbers | Where-Object { $_.contact_id -eq 'contact-001' }
            $phones.Count | Should -Be 2
            
            $phoneTypes = $phones.phone_type
            $phoneTypes | Should -Contain 'Mobile'
            $phoneTypes | Should -Contain 'Home'
        }
    }

    Context 'When processing relationship data' {
        It 'Should link relationships to correct contact' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $relationships = $result.Relationships | Where-Object { $_.contact_id -eq 'contact-001' }
            $relationships.Count | Should -Be 2
        }

        It 'Should map relationship fields correctly' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $relationship = $result.Relationships | Where-Object { 
                $_.contact_id -eq 'contact-001' -and $_.student_number -eq '12345' 
            }
            
            $relationship.relationship_type | Should -Be 'Father'
        }

        It 'Should convert boolean relationship fields' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $relationship = $result.Relationships[0]
            
            $relationship.legal_guardian | Should -Be $true
            $relationship.legal_guardian | Should -BeOfType [bool]
            $relationship.has_custody | Should -Be $true
            $relationship.has_custody | Should -BeOfType [bool]
            $relationship.lives_with | Should -Be $true
            $relationship.lives_with | Should -BeOfType [bool]
        }

        It 'Should handle multiple relationships per contact' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $relationships = $result.Relationships | Where-Object { $_.contact_id -eq 'contact-001' }
            $relationships.Count | Should -Be 2
            
            $studentNumbers = $relationships.student_number
            $studentNumbers | Should -Contain '12345'
            $studentNumbers | Should -Contain '67890'
        }

        It 'Should convert contact_priority_order to integer' {
            $result = ConvertTo-ParentStudentRelationships -CsvData $testParentData
            $relationship = $result.Relationships[0]
            $relationship.contact_priority_order | Should -Be 1
            $relationship.contact_priority_order | Should -BeOfType [int]
        }
    }

    Context 'When processing real example data' {
        BeforeAll {
            $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $ParentsPath = Join-Path $RepoRoot 'data/examples/parents_example.csv'
        }

        It 'Should process parents_example.csv if it exists' {
            if (Test-Path $ParentsPath) {
                $parents = Import-Csv $ParentsPath
                $result = ConvertTo-ParentStudentRelationships -CsvData $parents
                
                $result | Should -Not -BeNullOrEmpty
                $result.Contacts.Count | Should -BeGreaterThan 0
                $result.PhoneNumbers.Count | Should -BeGreaterThan 0
                $result.Relationships.Count | Should -BeGreaterThan 0
            }
        }

        It 'Should create valid contact records from example data' {
            if (Test-Path $ParentsPath) {
                $parents = Import-Csv $ParentsPath
                $result = ConvertTo-ParentStudentRelationships -CsvData $parents
                
                $firstContact = $result.Contacts[0]
                $firstContact.id | Should -Not -BeNullOrEmpty
                $firstContact.first_name | Should -Not -BeNullOrEmpty
                $firstContact.last_name | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should create valid phone records from example data' {
            if (Test-Path $ParentsPath) {
                $parents = Import-Csv $ParentsPath
                $result = ConvertTo-ParentStudentRelationships -CsvData $parents
                
                $firstPhone = $result.PhoneNumbers[0]
                $firstPhone.contact_id | Should -Not -BeNullOrEmpty
                $firstPhone.phone_number | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should create valid relationship records from example data' {
            if (Test-Path $ParentsPath) {
                $parents = Import-Csv $ParentsPath
                $result = ConvertTo-ParentStudentRelationships -CsvData $parents
                
                $firstRelationship = $result.Relationships[0]
                $firstRelationship.contact_id | Should -Not -BeNullOrEmpty
                $firstRelationship.student_number | Should -Not -BeNullOrEmpty
            }
        }
    }
}
