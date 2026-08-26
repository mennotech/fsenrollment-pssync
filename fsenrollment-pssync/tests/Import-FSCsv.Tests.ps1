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
            $Result.Contacts.Count | Should -Be 21
        }

        It 'Should import correct number of email addresses' {
            $Result.EmailAddresses.Count | Should -Be 21
        }

        It 'Should import correct number of phone numbers' {
            # 21 primary phones + 15 additional phones = 36 total (one contact with 3 phones excluded)
            $Result.PhoneNumbers.Count | Should -Be 36
        }

        It 'Should import correct number of addresses' {
            $Result.Addresses.Count | Should -Be 21
        }

        It 'Should import correct number of relationships' {
            $Result.Relationships.Count | Should -Be 30
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

    Context 'Parents CSV Exclude Functionality' {
        BeforeAll {
            $TestDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/parents_example.csv'
            $Result = Import-FSCsv -Path $TestDataPath -TemplateName 'fs_powerschool_nonapi_report_parents'
        }

        It 'Should exclude contacts with ExcludeFromExport set to true' {
            # Sunny Zimmer (e2857c92-c511-11ed-b1e3-025d0f476dca) should be excluded
            $ExcludedContact = $Result.Contacts | Where-Object { 
                $_.ContactIdentifier -eq 'e2857c92-c511-11ed-b1e3-025d0f476dca' 
            }
            $ExcludedContact | Should -BeNullOrEmpty
        }

        It 'Should exclude email addresses for excluded contacts' {
            # Email for Sunny Zimmer should be excluded
            $ExcludedEmail = $Result.EmailAddresses | Where-Object { 
                $_.ContactIdentifier -eq 'e2857c92-c511-11ed-b1e3-025d0f476dca' 
            }
            $ExcludedEmail | Should -BeNullOrEmpty
        }

        It 'Should exclude phone numbers for excluded contacts' {
            # All 3 phones for Sunny Zimmer should be excluded
            $ExcludedPhones = $Result.PhoneNumbers | Where-Object { 
                $_.ContactIdentifier -eq 'e2857c92-c511-11ed-b1e3-025d0f476dca' 
            }
            $ExcludedPhones | Should -BeNullOrEmpty
        }

        It 'Should exclude addresses for excluded contacts' {
            # Address for Sunny Zimmer should be excluded
            $ExcludedAddress = $Result.Addresses | Where-Object { 
                $_.ContactIdentifier -eq 'e2857c92-c511-11ed-b1e3-025d0f476dca' 
            }
            $ExcludedAddress | Should -BeNullOrEmpty
        }

        It 'Should exclude relationships for excluded contacts' {
            # Both relationships for Sunny Zimmer should be excluded
            $ExcludedRels = $Result.Relationships | Where-Object { 
                $_.ContactIdentifier -eq 'e2857c92-c511-11ed-b1e3-025d0f476dca' 
            }
            $ExcludedRels | Should -BeNullOrEmpty
        }

        It 'Should include contacts without ExcludeFromExport flag' {
            # Verify that other contacts are still imported
            $Result.Contacts.Count | Should -BeGreaterThan 0
            $FirstContact = $Result.Contacts[0]
            $FirstContact.ContactIdentifier | Should -Not -BeNullOrEmpty
        }
    }

    Context 'TemplateMetadata' {
        BeforeAll {
            $TestDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/parents_example.csv'
            $Result = Import-FSCsv -Path $TestDataPath -TemplateName 'fs_powerschool_nonapi_report_parents'
        }

        It 'Should include TemplateMetadata in result' {
            $Result.TemplateMetadata | Should -Not -BeNullOrEmpty
        }

        It 'Should include entire template configuration object' {
            $Result.TemplateMetadata.TemplateName | Should -Be 'fs_powerschool_nonapi_report_parents'
            $Result.TemplateMetadata.Description | Should -Not -BeNullOrEmpty
            $Result.TemplateMetadata.EntityType | Should -Be 'PSNormalizedData'
        }

        It 'Should include ValidationRules from template' {
            $Result.TemplateMetadata.ValidationRules | Should -Not -BeNullOrEmpty
            $Result.TemplateMetadata.ValidationRules.ValidRelationshipTypes | Should -Not -BeNullOrEmpty
        }

        It 'Should include all ValidRelationshipTypes' {
            $ValidTypes = $Result.TemplateMetadata.ValidationRules.ValidRelationshipTypes
            $ValidTypes | Should -Contain 'Mother'
            $ValidTypes | Should -Contain 'Father'
            $ValidTypes | Should -Contain 'Legal Guardian'
            $ValidTypes.Count | Should -BeGreaterThan 10
        }

        It 'Should include EntityTypeMap from template' {
            $Result.TemplateMetadata.EntityTypeMap | Should -Not -BeNullOrEmpty
            $Result.TemplateMetadata.EntityTypeMap.Contact | Should -Not -BeNullOrEmpty
            $Result.TemplateMetadata.EntityTypeMap.Relationship | Should -Not -BeNullOrEmpty
        }

        It 'Should include KeyField and PowerSchoolKeyField' {
            $Result.TemplateMetadata.KeyField | Should -Be 'ContactIdentifier'
            $Result.TemplateMetadata.PowerSchoolKeyField | Should -Be 'person_contactNumber'
        }

        It 'Should include DateTimeFormat' {
            $Result.TemplateMetadata.DateTimeFormat | Should -Be 'dd/MM/yyyy'
        }

        It 'Should include CustomParser reference' {
            $Result.TemplateMetadata.CustomParser | Should -Be 'Import-FSParentsCustomParser'
        }
    }

    Context 'Students TemplateMetadata' {
        BeforeAll {
            $TestDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/students_example.csv'
            $Result = Import-FSCsv -Path $TestDataPath -TemplateName 'fs_powerschool_nonapi_report_students'
        }

        It 'Should include entire template configuration for students template' {
            $Result.TemplateMetadata | Should -Not -BeNullOrEmpty
            $Result.TemplateMetadata.TemplateName | Should -Be 'fs_powerschool_nonapi_report_students'
        }

        It 'Should include ColumnMappings from template' {
            $Result.TemplateMetadata.ColumnMappings | Should -Not -BeNullOrEmpty
            $Result.TemplateMetadata.ColumnMappings.Count | Should -BeGreaterThan 0
        }
    }
}
