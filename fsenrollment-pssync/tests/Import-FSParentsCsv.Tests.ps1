#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../fsenrollment-pssync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Import-FSParentsCsv' {
    BeforeAll {
        $TestDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/parents_example.csv'
    }

    Context 'Parameter Validation' {
        It 'Should throw error if file does not exist' {
            { Import-FSParentsCsv -Path '/nonexistent/file.csv' -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'CSV Parsing - Basic Counts' {
        BeforeAll {
            $Result = Import-FSParentsCsv -Path $TestDataPath
        }

        It 'Should return PSNormalizedData object' {
            $Result | Should -Not -BeNullOrEmpty
            $Result.GetType().Name | Should -Be 'PSNormalizedData'
        }

        It 'Should import correct number of contacts' {
            $Result.Contacts.Count | Should -Be 22
        }

        It 'Should import correct number of email addresses' {
            $Result.EmailAddresses.Count | Should -Be 22
        }

        It 'Should import correct number of phone numbers' {
            # 22 primary phones + 17 additional phones = 39 total
            $Result.PhoneNumbers.Count | Should -Be 39
        }

        It 'Should import correct number of addresses' {
            $Result.Addresses.Count | Should -Be 22
        }

        It 'Should import correct number of relationships' {
            $Result.Relationships.Count | Should -Be 32
        }

        It 'Should have empty Students collection' {
            $Result.Students.Count | Should -Be 0
        }
    }

    Context 'Contact Data Parsing' {
        BeforeAll {
            $Result = Import-FSParentsCsv -Path $TestDataPath
            $FirstContact = $Result.Contacts[0]
        }

        It 'Should parse contact identifier correctly' {
            $FirstContact.ContactIdentifier | Should -Be '87020242-99aa-11ec-b1e3-025d0f476dca'
        }

        It 'Should parse contact name correctly' {
            $FirstContact.FirstName | Should -Be 'Arden'
            $FirstContact.LastName | Should -Be 'Hayes'
        }

        It 'Should parse contact prefix correctly' {
            $FirstContact.Prefix | Should -Be 'Mr.'
        }

        It 'Should parse contact gender correctly' {
            $FirstContact.Gender | Should -Be 'M'
        }

        It 'Should parse contact employer correctly' {
            $FirstContact.Employer | Should -Be 'self employed'
        }

        It 'Should parse IsActive as boolean' {
            $FirstContact.IsActive | Should -Be $true
        }

        It 'Should not have duplicate contacts' {
            $ContactIds = $Result.Contacts | ForEach-Object { $_.ContactIdentifier }
            $UniqueIds = $ContactIds | Select-Object -Unique
            $UniqueIds.Count | Should -Be $ContactIds.Count
        }
    }

    Context 'Email Address Parsing' {
        BeforeAll {
            $Result = Import-FSParentsCsv -Path $TestDataPath
            $FirstEmail = $Result.EmailAddresses | Where-Object { $_.ContactIdentifier -eq '87020242-99aa-11ec-b1e3-025d0f476dca' }
        }

        It 'Should parse email address correctly' {
            $FirstEmail.EmailAddress | Should -Be 'arden.hayes54@gmail.com'
        }

        It 'Should parse IsPrimary as boolean' {
            $FirstEmail.IsPrimary | Should -Be $true
        }

        It 'Should link email to correct contact' {
            $FirstEmail.ContactIdentifier | Should -Be '87020242-99aa-11ec-b1e3-025d0f476dca'
        }
    }

    Context 'Phone Number Parsing' {
        BeforeAll {
            $Result = Import-FSParentsCsv -Path $TestDataPath
        }

        It 'Should parse primary phone number' {
            $FirstPhone = $Result.PhoneNumbers | Where-Object { 
                $_.ContactIdentifier -eq '87020242-99aa-11ec-b1e3-025d0f476dca' 
            }
            $FirstPhone.PhoneNumber | Should -Be '151-275-1722'
            $FirstPhone.PhoneType | Should -Be 'Mobile'
        }

        It 'Should handle multiple phone numbers for same contact' {
            # Contact 87c3fcca has 3 phone numbers
            $Phones = $Result.PhoneNumbers | Where-Object { 
                $_.ContactIdentifier -eq '87c3fcca-99aa-11ec-b1e3-025d0f476dca' 
            }
            $Phones.Count | Should -Be 3
        }

        It 'Should parse phone priority order' {
            $Phones = $Result.PhoneNumbers | Where-Object { 
                $_.ContactIdentifier -eq '87c3fcca-99aa-11ec-b1e3-025d0f476dca' 
            }
            $PriorityOrders = $Phones | ForEach-Object { $_.PriorityOrder } | Sort-Object
            $PriorityOrders | Should -Contain 1
            $PriorityOrders | Should -Contain 2
            $PriorityOrders | Should -Contain 3
        }

        It 'Should parse different phone types' {
            $PhoneTypes = $Result.PhoneNumbers | ForEach-Object { $_.PhoneType } | Select-Object -Unique
            $PhoneTypes | Should -Contain 'Mobile'
            $PhoneTypes | Should -Contain 'Home'
            $PhoneTypes | Should -Contain 'Work'
        }
    }

    Context 'Address Parsing' {
        BeforeAll {
            $Result = Import-FSParentsCsv -Path $TestDataPath
            $FirstAddress = $Result.Addresses | Where-Object { 
                $_.ContactIdentifier -eq '87020242-99aa-11ec-b1e3-025d0f476dca' 
            }
        }

        It 'Should parse street address' {
            $FirstAddress.Street | Should -Be '332 Deer Street'
        }

        It 'Should parse city' {
            $FirstAddress.City | Should -Be 'Quebec City'
        }

        It 'Should parse state' {
            $FirstAddress.State | Should -Be 'QC'
        }

        It 'Should parse postal code' {
            $FirstAddress.PostalCode | Should -Be 'W5K 1B7'
        }

        It 'Should parse address type' {
            $FirstAddress.AddressType | Should -Be 'Home'
        }
    }

    Context 'Relationship Parsing' {
        BeforeAll {
            $Result = Import-FSParentsCsv -Path $TestDataPath
        }

        It 'Should parse student number in relationship' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.StudentNumber | Should -Be '316301'
        }

        It 'Should parse student name in relationship' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.StudentName | Should -Be 'Morgan Hayes'
        }

        It 'Should parse relationship type' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.RelationshipType | Should -Be 'Father'
        }

        It 'Should parse contact priority order' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.ContactPriorityOrder | Should -Be 1
        }

        It 'Should parse boolean flags correctly' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.IsLegalGuardian | Should -Be $true
            $FirstRel.HasCustody | Should -Be $true
            $FirstRel.LivesWith | Should -Be $true
            $FirstRel.AllowSchoolPickup | Should -Be $true
            $FirstRel.IsEmergencyContact | Should -Be $true
            $FirstRel.ReceivesMail | Should -Be $true
        }

        It 'Should link relationship to correct contact' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.ContactIdentifier | Should -Be '87020242-99aa-11ec-b1e3-025d0f476dca'
        }

        It 'Should handle multiple relationships per student' {
            # Student 316301 has 2 relationships (Father and Mother)
            $StudentRels = $Result.Relationships | Where-Object { $_.StudentNumber -eq '316301' }
            $StudentRels.Count | Should -Be 2
            $StudentRels.RelationshipType | Should -Contain 'Father'
            $StudentRels.RelationshipType | Should -Contain 'Mother'
        }

        It 'Should handle multiple students per contact' {
            # Contact d39a8193-e5a3-11ec-b1e3-025d0f476dca is linked to 3 students
            $ContactRels = $Result.Relationships | Where-Object { 
                $_.ContactIdentifier -eq 'd39a8193-e5a3-11ec-b1e3-025d0f476dca' 
            }
            $ContactRels.Count | Should -Be 3
        }

        It 'Should handle LivesWith flag variations' {
            # Some relationships have LivesWith = 0
            $FalseRels = $Result.Relationships | Where-Object { $_.LivesWith -eq $false }
            $FalseRels.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Complex Multi-Row Format' {
        BeforeAll {
            $Result = Import-FSParentsCsv -Path $TestDataPath
        }

        It 'Should correctly identify contact rows vs phone rows vs relationship rows' {
            # Verify we have the expected structure
            # 22 unique contacts, 39 phone numbers (some contacts have multiple), 32 relationships
            $Result.Contacts.Count | Should -Be 22
            $Result.PhoneNumbers.Count | Should -Be 39
            $Result.Relationships.Count | Should -Be 32
        }

        It 'Should handle contacts with only one phone number' {
            $ContactPhones = $Result.PhoneNumbers | Where-Object { 
                $_.ContactIdentifier -eq '87020242-99aa-11ec-b1e3-025d0f476dca' 
            }
            $ContactPhones.Count | Should -Be 1
        }

        It 'Should handle contacts with multiple phone numbers' {
            $ContactPhones = $Result.PhoneNumbers | Where-Object { 
                $_.ContactIdentifier -eq '87b573df-99aa-11ec-b1e3-025d0f476dca' 
            }
            $ContactPhones.Count | Should -Be 2
        }
    }
}
