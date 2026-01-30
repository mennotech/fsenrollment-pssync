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
        # All initialization will be done within InModuleScope in individual tests
        # to ensure classes are available
    }

    Context 'New Students Detection' {
        It 'Should identify new students not in PowerSchool' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                
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
            }
        }

        It 'Should identify multiple new students' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                
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
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:CsvData.TemplateMetadata = @{
                    CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'GradeLevel')
                    ColumnMappings = @(
                        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' },
                        @{ EntityProperty = 'MiddleName'; PowerSchoolAPIField = 'name.middle_name' },
                        @{ EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' },
                        @{ EntityProperty = 'GradeLevel'; PowerSchoolAPIField = 'grade_level' }
                    )
                }
                
                # CSV student
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '123456'
                $csvStudent.FirstName = 'John'
                $csvStudent.LastName = 'Doe'
                $csvStudent.GradeLevel = 11
                $script:CsvData.Students.Add($csvStudent)
                
                # PowerSchool student with different grade
                $psStudent = @{
                    local_id = '123456'
                    name = @{
                        first_name = 'John'
                        last_name = 'Doe'
                    }
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
        }

        It 'Should detect multiple field changes' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:CsvData.TemplateMetadata = @{
                    CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'GradeLevel')
                    ColumnMappings = @(
                        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' },
                        @{ EntityProperty = 'MiddleName'; PowerSchoolAPIField = 'name.middle_name' },
                        @{ EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' },
                        @{ EntityProperty = 'GradeLevel'; PowerSchoolAPIField = 'grade_level' }
                    )
                }
                
                # CSV student
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '123456'
                $csvStudent.FirstName = 'Jane'
                $csvStudent.LastName = 'Smith'
                $csvStudent.GradeLevel = 11
                $script:CsvData.Students.Add($csvStudent)
                
                # PowerSchool student with different name and grade
                $psStudent = @{
                    local_id = '123456'
                    name = @{
                        first_name = 'John'
                        last_name = 'Doe'
                    }
                    grade_level = 10
                }
                $script:PowerSchoolData = @($psStudent)
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Updated.Count | Should -Be 1
                $result.Updated[0].Changes.Count | Should -BeGreaterOrEqual 3
            }
        }

        It 'Should handle null and empty string values correctly' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:CsvData.TemplateMetadata = @{
                    ColumnMappings = @(
                        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' },
                        @{ EntityProperty = 'MiddleName'; PowerSchoolAPIField = 'name.middle_name' },
                        @{ EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                    )
                }
                
                # CSV student with empty middle name
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '123456'
                $csvStudent.FirstName = 'John'
                $csvStudent.MiddleName = ''
                $csvStudent.LastName = 'Doe'
                $script:CsvData.Students.Add($csvStudent)
                
                # PowerSchool student with null middle name
                $psStudent = @{
                    local_id = '123456'
                    name = @{
                        first_name = 'John'
                        middle_name = $null
                        last_name = 'Doe'
                    }
                }
                $script:PowerSchoolData = @($psStudent)
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                # Empty string and null should be treated as equal
                $result.Unchanged.Count | Should -Be 1
                $result.Updated.Count | Should -Be 0
            }
        }
    }

    Context 'Unchanged Students Detection' {
        It 'Should identify students with no changes' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:CsvData.TemplateMetadata = @{
                    ColumnMappings = @(
                        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' },
                        @{ EntityProperty = 'MiddleName'; PowerSchoolAPIField = 'name.middle_name' },
                        @{ EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                    )
                }
                
                # CSV student
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '123456'
                $csvStudent.FirstName = 'John'
                $csvStudent.LastName = 'Doe'
                $csvStudent.GradeLevel = 10
                $script:CsvData.Students.Add($csvStudent)
                
                # PowerSchool student identical to CSV
                $psStudent = @{
                    local_id = '123456'
                    name = @{
                        first_name = 'John'
                        last_name = 'Doe'
                    }
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
    }

    Context 'Removed Students Detection' {
        It 'Should NOT detect removed students (students in PowerSchool but not in CSV)' {
            InModuleScope FSEnrollment-PSSync {
                # CSV has no students
                $script:CsvData = [PSNormalizedData]::new()
                
                # PowerSchool has a student
                $psStudent = @{
                    local_id = '123456'
                    name = @{
                        first_name = 'John'
                        last_name = 'Doe'
                    }
                    grade_level = 10
                }
                $script:PowerSchoolData = @($psStudent)
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                # Should not have a Removed property
                $result.PSObject.Properties.Name -contains 'Removed' | Should -Be $false
                # Summary should not have RemovedCount
                $result.Summary.PSObject.Properties.Name -contains 'RemovedCount' | Should -Be $false
            }
        }

        It 'Should not track removed students when CSV has fewer students than PowerSchool' {
            InModuleScope FSEnrollment-PSSync {
                # CSV has no students
                $script:CsvData = [PSNormalizedData]::new()
                
                # PowerSchool has multiple students
                $script:PowerSchoolData = @(
                    @{ local_id = '111'; name = @{ first_name = 'Student'; last_name = 'One' } },
                    @{ local_id = '222'; name = @{ first_name = 'Student'; last_name = 'Two' } },
                    @{ local_id = '333'; name = @{ first_name = 'Student'; last_name = 'Three' } }
                )
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                # Should not have a Removed property
                $result.PSObject.Properties.Name -contains 'Removed' | Should -Be $false
                # Summary should not have RemovedCount
                $result.Summary.PSObject.Properties.Name -contains 'RemovedCount' | Should -Be $false
            }
        }
    }

    Context 'Match Field Options' {
        It 'Should match on StudentNumber by default' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:CsvData.TemplateMetadata = @{
                    ColumnMappings = @(
                        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                    )
                }
                
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '123456'
                $csvStudent.FTEID = 'ABCD1234'
                $csvStudent.FirstName = 'John'
                $script:CsvData.Students.Add($csvStudent)
                
                $psStudent = @{
                    local_id = '123456'
                    fteid = 'DIFFERENT'
                    name = @{
                        first_name = 'John'
                    }
                }
                $script:PowerSchoolData = @($psStudent)
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                # Should match on student_number, not fteid
                $result.Unchanged.Count | Should -Be 1
                $result.New.Count | Should -Be 0
            }
        }

        It 'Should match on FTEID when specified' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:CsvData.TemplateMetadata = @{
                    KeyField = 'FTEID'
                    PowerSchoolKeyField = 'fteid'
                    ColumnMappings = @(
                        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                    )
                }
                
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '999999'
                $csvStudent.FTEID = 'ABCD1234'
                $csvStudent.FirstName = 'John'
                $script:CsvData.Students.Add($csvStudent)
                
                $psStudent = @{
                    local_id = '123456'
                    fteid = 'ABCD1234'
                    name = @{
                        first_name = 'John'
                    }
                }
                $script:PowerSchoolData = @($psStudent)
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                # Should match on fteid, not student_number
                $result.Unchanged.Count | Should -Be 1
                $result.New.Count | Should -Be 0
            }
        }
    }

    Context 'Summary Report' {
        It 'Should include correct counts in summary' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:CsvData.TemplateMetadata = @{
                    CheckForChanges = @('FirstName', 'MiddleName', 'LastName')
                    ColumnMappings = @(
                        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' },
                        @{ EntityProperty = 'MiddleName'; PowerSchoolAPIField = 'name.middle_name' },
                        @{ EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                    )
                }
                
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
                    @{ local_id = 'UNCHANGED'; name = @{ first_name = 'Same' } },
                    @{ local_id = 'UPDATED'; name = @{ first_name = 'OldName' } },
                    @{ local_id = 'REMOVED'; name = @{ first_name = 'Gone' } }
                )
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.Summary.NewCount | Should -Be 2
                $result.Summary.UpdatedCount | Should -Be 1
                $result.Summary.UnchangedCount | Should -Be 1
                $result.Summary.TotalInCsv | Should -Be 4
                $result.Summary.TotalInPowerSchool | Should -Be 3
            }
        }

        It 'Should include match field in summary' {
            InModuleScope FSEnrollment-PSSync {
                $script:CsvData = [PSNormalizedData]::new()
                $script:PowerSchoolData = @()
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                $result.Summary.MatchField | Should -Be 'StudentNumber'
                
                # Test with FTEID template metadata
                $script:CsvData.TemplateMetadata.KeyField = 'FTEID'
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                $result.Summary.MatchField | Should -Be 'FTEID'
            }
        }
    }

    Context 'Edge Cases' {
        It 'Should handle empty CSV data' {
            InModuleScope FSEnrollment-PSSync {
                $script:CsvData = [PSNormalizedData]::new()
                $script:PowerSchoolData = @()
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.New.Count | Should -Be 0
                $result.Updated.Count | Should -Be 0
                $result.Unchanged.Count | Should -Be 0
            }
        }

        It 'Should handle empty PowerSchool data' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                
                $csvStudent = [PSStudent]::new()
                $csvStudent.StudentNumber = '123456'
                $script:CsvData.Students.Add($csvStudent)
                $script:PowerSchoolData = @()
                
                $result = Compare-PSStudent -CsvData $script:CsvData -PowerSchoolData $script:PowerSchoolData
                
                $result.New.Count | Should -Be 1
            }
        }

        It 'Should skip CSV students with missing match field' {
            InModuleScope FSEnrollment-PSSync {
                # Initialize data
                $script:CsvData = [PSNormalizedData]::new()
                $script:PowerSchoolData = @()
                
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
}
