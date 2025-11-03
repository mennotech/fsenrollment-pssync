#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../fsenrollment-pssync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Import-FSStudentsCsv' {
    BeforeAll {
        $TestDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/students_example.csv'
    }

    Context 'Parameter Validation' {
        It 'Should throw error if file does not exist' {
            { Import-FSStudentsCsv -Path '/nonexistent/file.csv' -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'CSV Parsing' {
        BeforeAll {
            $Result = Import-FSStudentsCsv -Path $TestDataPath
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
    }

    Context 'Multiple Students' {
        BeforeAll {
            $Result = Import-FSStudentsCsv -Path $TestDataPath
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
}
