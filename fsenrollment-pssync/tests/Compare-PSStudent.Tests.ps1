#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
    
    # Define helper script to create test data within module scope
    $script:CreateTestCsvData = {
        param([int]$StudentCount = 0)
        $csvData = [PSNormalizedData]::new()
        for ($i = 1; $i -le $StudentCount; $i++) {
            $student = [PSStudent]::new()
            $student.StudentNumber = "12345$i"
            $student.FirstName = "Student$i"
            $student.LastName = "Test"
            $csvData.Students.Add($student)
        }
        return $csvData
    }
}

Describe 'Compare-PSStudent' {
    BeforeEach {
        # Create sample data using InModuleScope
        InModuleScope FSEnrollment-PSSync {
            $script:CsvData = [PSNormalizedData]::new()
            $script:PowerSchoolData = @()
        }
    }

    Context 'New Students Detection' {
        It 'Should identify new students not in PowerSchool' {
            InModuleScope FSEnrollment-PSSync {
                # Add students to CSV data
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '123456'
                $csvStudent.FirstName = 'John'
                $csvStudent.LastName = 'Doe'
                $csvStudent.GradeLevel = 10
                $script:CsvData.Students.Add($csvStudent)
                
                # PowerSchool has no students
                $script:PowerSchoolData = @()
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.New.Count | Should -Be 1
                $result.New[0].MatchKey | Should -Be '123456'
                $result.Updated.Count | Should -Be 0
                $result.Unchanged.Count | Should -Be 0
                $result.Removed.Count | Should -Be 0
            }
        }

        It 'Should identify multiple new students' {
            InModuleScope FSEnrollment-PSSync {
                # Add multiple students to CSV
                1..3 | ForEach-Object {
                    $student = [PSStudent]::new()
                    $student.StudentNumber = "12345$_"
                    $student.FirstName = "Student$_"
                    $student.LastName = "Test"
                    $script:CsvData.Students.Add($student)
                }
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData @()
                
                $result.New.Count | Should -Be 3
                $result.Summary.NewCount | Should -Be 3
            }
        }
    }

    Context 'Updated Students Detection' {
        It 'Should identify students with changed fields' {
            # CSV student
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = '123456'
            $csvStudent.FirstName = 'John'
            $csvStudent.LastName = 'Doe'
            $csvStudent.GradeLevel = 11
            $script:CsvData.Students.Add($csvStudent)
            
            # PowerSchool student with different grade
            $psStudent = @{
                student_number = '123456'
                first_name = 'John'
                last_name = 'Doe'
                grade_level = 10
            }
            $script:PowerSchoolData = @($psStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.Updated.Count | Should -Be 1
            $result.Updated[0].MatchKey | Should -Be '123456'
            $result.Updated[0].Changes.Count | Should -BeGreaterThan 0
            
            # Check that GradeLevel is in the changes
            $gradeChange = $result.Updated[0].Changes | Where-Object { $_.Field -eq 'GradeLevel' }
            $gradeChange | Should -Not -BeNullOrEmpty
            $gradeChange.OldValue | Should -Be '10'
            $gradeChange.NewValue | Should -Be '11'
        }

        It 'Should detect multiple field changes' {
            # CSV student
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = '123456'
            $csvStudent.FirstName = 'Jane'
            $csvStudent.LastName = 'Smith'
            $csvStudent.GradeLevel = 11
            $script:CsvData.Students.Add($csvStudent)
            
            # PowerSchool student with different name and grade
            $psStudent = @{
                student_number = '123456'
                first_name = 'John'
                last_name = 'Doe'
                grade_level = 10
            }
            $script:PowerSchoolData = @($psStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.Updated.Count | Should -Be 1
            $result.Updated[0].Changes.Count | Should -BeGreaterOrEqual 3
        }

        It 'Should handle null and empty string values correctly' {
            # CSV student with empty middle name
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = '123456'
            $csvStudent.FirstName = 'John'
            $csvStudent.MiddleName = ''
            $csvStudent.LastName = 'Doe'
            $script:CsvData.Students.Add($csvStudent)
            
            # PowerSchool student with null middle name
            $psStudent = @{
                student_number = '123456'
                first_name = 'John'
                middle_name = $null
                last_name = 'Doe'
            }
            $script:PowerSchoolData = @($psStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            # Empty string and null should be treated as equal
            $result.Unchanged.Count | Should -Be 1
            $result.Updated.Count | Should -Be 0
        }
    }

    Context 'Unchanged Students Detection' {
        It 'Should identify students with no changes' {
            # CSV student
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = '123456'
            $csvStudent.FirstName = 'John'
            $csvStudent.LastName = 'Doe'
            $csvStudent.GradeLevel = 10
            $script:CsvData.Students.Add($csvStudent)
            
            # PowerSchool student identical to CSV
            $psStudent = @{
                student_number = '123456'
                first_name = 'John'
                last_name = 'Doe'
                grade_level = 10
            }
            $script:PowerSchoolData = @($psStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.Unchanged.Count | Should -Be 1
            $result.Unchanged[0].MatchKey | Should -Be '123456'
            $result.Updated.Count | Should -Be 0
            $result.New.Count | Should -Be 0
        }
    }

    Context 'Removed Students Detection' {
        It 'Should identify students in PowerSchool but not in CSV' {
            # CSV has no students
            $script:CsvData = [PSNormalizedData]::new()
            
            # PowerSchool has a student
            $psStudent = @{
                student_number = '123456'
                first_name = 'John'
                last_name = 'Doe'
                grade_level = 10
            }
            $script:PowerSchoolData = @($psStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.Removed.Count | Should -Be 1
            $result.Removed[0].MatchKey | Should -Be '123456'
        }

        It 'Should identify multiple removed students' {
            # CSV has no students
            $script:CsvData = [PSNormalizedData]::new()
            
            # PowerSchool has multiple students
            $script:PowerSchoolData = @(
                @{ student_number = '111'; first_name = 'Student'; last_name = 'One' },
                @{ student_number = '222'; first_name = 'Student'; last_name = 'Two' },
                @{ student_number = '333'; first_name = 'Student'; last_name = 'Three' }
            )
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.Removed.Count | Should -Be 3
            $result.Summary.RemovedCount | Should -Be 3
        }
    }

    Context 'Match Field Options' {
        It 'Should match on StudentNumber by default' {
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = '123456'
            $csvStudent.FTEID = 'ABCD1234'
            $csvStudent.FirstName = 'John'
            $script:CsvData.Students.Add($csvStudent)
            
            $psStudent = @{
                student_number = '123456'
                fteid = 'DIFFERENT'
                first_name = 'John'
            }
            $script:PowerSchoolData = @($psStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            # Should match on student_number, not fteid
            $result.Unchanged.Count | Should -Be 1
            $result.New.Count | Should -Be 0
        }

        It 'Should match on FTEID when specified' {
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = '999999'
            $csvStudent.FTEID = 'ABCD1234'
            $csvStudent.FirstName = 'John'
            $script:CsvData.Students.Add($csvStudent)
            
            $psStudent = @{
                student_number = '123456'
                fteid = 'ABCD1234'
                first_name = 'John'
            }
            $script:PowerSchoolData = @($psStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData -MatchOn 'FTEID'
            
            # Should match on fteid, not student_number
            $result.Unchanged.Count | Should -Be 1
            $result.New.Count | Should -Be 0
        }
    }

    Context 'Summary Report' {
        It 'Should include correct counts in summary' {
            # Add 2 new students
            1..2 | ForEach-Object {
                $student = [PSStudent]::new()
                $student.StudentNumber = "NEW$_"
                $student.FirstName = "New$_"
                $script:CsvData.Students.Add($student)
            }
            
            # Add 1 unchanged student
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = 'UNCHANGED'
            $csvStudent.FirstName = 'Same'
            $script:CsvData.Students.Add($csvStudent)
            
            # Add 1 updated student
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = 'UPDATED'
            $csvStudent.FirstName = 'NewName'
            $script:CsvData.Students.Add($csvStudent)
            
            # PowerSchool data
            $script:PowerSchoolData = @(
                @{ student_number = 'UNCHANGED'; first_name = 'Same' },
                @{ student_number = 'UPDATED'; first_name = 'OldName' },
                @{ student_number = 'REMOVED'; first_name = 'Gone' }
            )
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.Summary.NewCount | Should -Be 2
            $result.Summary.UpdatedCount | Should -Be 1
            $result.Summary.UnchangedCount | Should -Be 1
            $result.Summary.RemovedCount | Should -Be 1
            $result.Summary.TotalInCsv | Should -Be 4
            $result.Summary.TotalInPowerSchool | Should -Be 3
        }

        It 'Should include match field in summary' {
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            $result.Summary.MatchField | Should -Be 'StudentNumber'
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData -MatchOn 'FTEID'
            $result.Summary.MatchField | Should -Be 'FTEID'
        }
    }

    Context 'Edge Cases' {
        It 'Should handle empty CSV data' {
            $script:CsvData = [PSNormalizedData]::new()
            $script:PowerSchoolData = @()
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.New.Count | Should -Be 0
            $result.Updated.Count | Should -Be 0
            $result.Unchanged.Count | Should -Be 0
            $result.Removed.Count | Should -Be 0
        }

        It 'Should handle empty PowerSchool data' {
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = '123456'
            $script:CsvData.Students.Add($csvStudent)
            $script:PowerSchoolData = @()
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            $result.New.Count | Should -Be 1
            $result.Removed.Count | Should -Be 0
        }

        It 'Should skip CSV students with missing match field' {
            # Student with no StudentNumber
            $csvStudent = [PSStudent]::new()
            $csvStudent.StudentNumber = ''
            $csvStudent.FirstName = 'John'
            $script:CsvData.Students.Add($csvStudent)
            
            $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
            
            # Should not throw, but should skip this student
            $result.New.Count | Should -Be 0
        }
    }
}
