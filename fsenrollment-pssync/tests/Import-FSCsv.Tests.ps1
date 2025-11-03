#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Import-FSCsv' {
    Context 'Parameter Validation' {
        It 'Should throw error if file does not exist' {
            { Import-FSCsv -Path '/nonexistent/file.csv' -TemplateName 'fs_powerschool_nonapi_report_students' -ErrorAction Stop } | Should -Throw
        }

        It 'Should throw error if template does not exist' {
            $TempFile = New-TemporaryFile
            'col1,col2' | Out-File $TempFile
            { Import-FSCsv -Path $TempFile -TemplateName 'nonexistent_template' -ErrorAction Stop } | Should -Throw
            Remove-Item $TempFile
        }
    }

    Context 'Students CSV Parsing' {
        BeforeAll {
            $TestDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/students_example.csv'
            $Result = Import-FSCsv -Path $TestDataPath -TemplateName 'fs_powerschool_nonapi_report_students'
        }

        It 'Should return PSNormalizedData object' {
            $Result | Should -Not -BeNullOrEmpty
            $Result.GetType().Name | Should -Be 'PSNormalizedData'
        }

        It 'Should import correct number of students' {
            $Result.Students.Count | Should -Be 19
        }

        It 'Should have empty collections for non-student data' {
            $Result.Contacts.Count | Should -Be 0
            $Result.EmailAddresses.Count | Should -Be 0
            $Result.PhoneNumbers.Count | Should -Be 0
            $Result.Addresses.Count | Should -Be 0
            $Result.Relationships.Count | Should -Be 0
        }

        It 'Should parse student data correctly' {
            $FirstStudent = $Result.Students[0]
            $FirstStudent.StudentNumber | Should -Be '313202'
            $FirstStudent.FirstName | Should -Be 'Arden'
            $FirstStudent.LastName | Should -Be 'Griffin'
            $FirstStudent.SchoolID | Should -Be '300'
            $FirstStudent.GradeLevel | Should -Be 12
            $FirstStudent.Gender | Should -Be 'F'
        }

        It 'Should parse dates correctly' {
            $FirstStudent = $Result.Students[0]
            $FirstStudent.DOB.Year | Should -Be 2007
            $FirstStudent.DOB.Month | Should -Be 6
            $FirstStudent.DOB.Day | Should -Be 19
        }

        It 'Should parse addresses correctly' {
            $FirstStudent = $Result.Students[0]
            $FirstStudent.Street | Should -Be '33 Poplar Bay'
            $FirstStudent.City | Should -Be 'Winnipeg'
            $FirstStudent.State | Should -Be 'QC'
            $FirstStudent.Zip | Should -Be 'E0T 8N0'
        }

        It 'Should parse mailing addresses correctly' {
            $FirstStudent = $Result.Students[0]
            $FirstStudent.MailingStreet | Should -Be '08 Hillcrest Crescent'
            $FirstStudent.MailingCity | Should -Be 'Montreal'
            $FirstStudent.MailingState | Should -Be 'NL'
            $FirstStudent.MailingZip | Should -Be 'T1Y 6N1'
        }

        It 'Should parse integers correctly' {
            $FirstStudent = $Result.Students[0]
            $FirstStudent.SchedNextYearGrade | Should -Be 99
            $FirstStudent.SchedYearOfGraduation | Should -Be 2026
            $FirstStudent.EnrollStatus | Should -Be 0
        }

        It 'Should parse FamilyIdent correctly' {
            $FirstStudent = $Result.Students[0]
            $FirstStudent.FamilyIdent | Should -Be '3632'
        }

        It 'Should import all students with unique student numbers' {
            $StudentNumbers = $Result.Students | ForEach-Object { $_.StudentNumber }
            $UniqueStudentNumbers = $StudentNumbers | Select-Object -Unique
            $UniqueStudentNumbers.Count | Should -Be $StudentNumbers.Count
        }

        It 'Should parse different grade levels correctly' {
            $GradeLevels = $Result.Students | ForEach-Object { $_.GradeLevel } | Sort-Object -Unique
            $GradeLevels | Should -Contain 0
            $GradeLevels | Should -Contain 12
        }
    }

    Context 'Parents CSV Parsing' {
        BeforeAll {
            $TestDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/parents_example.csv'
            $Result = Import-FSCsv -Path $TestDataPath -TemplateName 'fs_powerschool_nonapi_report_parents'
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

        It 'Should parse contact data correctly' {
            $FirstContact = $Result.Contacts[0]
            $FirstContact.ContactIdentifier | Should -Be '87020242-99aa-11ec-b1e3-025d0f476dca'
            $FirstContact.FirstName | Should -Be 'Arden'
            $FirstContact.LastName | Should -Be 'Hayes'
            $FirstContact.Prefix | Should -Be 'Mr.'
            $FirstContact.Gender | Should -Be 'M'
            $FirstContact.Employer | Should -Be 'self employed'
            $FirstContact.IsActive | Should -Be $true
        }

        It 'Should not have duplicate contacts' {
            $ContactIds = $Result.Contacts | ForEach-Object { $_.ContactIdentifier }
            $UniqueIds = $ContactIds | Select-Object -Unique
            $UniqueIds.Count | Should -Be $ContactIds.Count
        }

        It 'Should parse email addresses correctly' {
            $FirstEmail = $Result.EmailAddresses | Where-Object { $_.ContactIdentifier -eq '87020242-99aa-11ec-b1e3-025d0f476dca' }
            $FirstEmail.EmailAddress | Should -Be 'arden.hayes54@gmail.com'
            $FirstEmail.IsPrimary | Should -Be $true
        }

        It 'Should parse phone numbers correctly' {
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

        It 'Should parse addresses correctly' {
            $FirstAddress = $Result.Addresses | Where-Object { 
                $_.ContactIdentifier -eq '87020242-99aa-11ec-b1e3-025d0f476dca' 
            }
            $FirstAddress.Street | Should -Be '332 Deer Street'
            $FirstAddress.City | Should -Be 'Quebec City'
            $FirstAddress.State | Should -Be 'QC'
            $FirstAddress.PostalCode | Should -Be 'W5K 1B7'
            $FirstAddress.AddressType | Should -Be 'Home'
        }

        It 'Should parse relationships correctly' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.StudentNumber | Should -Be '316301'
            $FirstRel.StudentName | Should -Be 'Morgan Hayes'
            $FirstRel.RelationshipType | Should -Be 'Father'
            $FirstRel.ContactPriorityOrder | Should -Be 1
        }

        It 'Should parse relationship boolean flags correctly' {
            $FirstRel = $Result.Relationships[0]
            $FirstRel.IsLegalGuardian | Should -Be $true
            $FirstRel.HasCustody | Should -Be $true
            $FirstRel.LivesWith | Should -Be $true
            $FirstRel.AllowSchoolPickup | Should -Be $true
            $FirstRel.IsEmergencyContact | Should -Be $true
            $FirstRel.ReceivesMail | Should -Be $true
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
    }
}
