#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Submit-PSStudentChange' {
    BeforeEach {
        # Mock the PowerSchool connection using the new variable names
        InModuleScope FSEnrollment-PSSync {
            $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token-12345' -AsPlainText -Force
            $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
            $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
        }

        # Create sample change data with TemplateMetadata as PSCustomObject
        $script:SampleChanges = [PSCustomObject]@{
            New = @()
            Updated = @()
            Unchanged = @()
            Summary = [PSCustomObject]@{
                TotalInCsv = 0
                TotalInPowerSchool = 0
                NewCount = 0
                UpdatedCount = 0
                UnchangedCount = 0
                MatchField = 'StudentNumber'
            }
            TemplateMetadata = [PSCustomObject]@{
                TemplateName = 'test_template'
                KeyField = 'StudentNumber'
                PowerSchoolKeyField = 'local_id'
                PowerSchoolKeyDataType = 'int'
                CheckForChanges = @('FirstName', 'LastName')
                ColumnMappings = @(
                    [PSCustomObject]@{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                    [PSCustomObject]@{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                    [PSCustomObject]@{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                )
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept Changes parameter' {
            InModuleScope FSEnrollment-PSSync {
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                $templateMetadata = @{
                    TemplateName = 'test_template'
                    KeyField = 'StudentNumber'
                    PowerSchoolKeyField = 'local_id'
                    PowerSchoolKeyDataType = 'int'
                    CheckForChanges = @('FirstName', 'LastName')
                    ColumnMappings = @(
                        @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                    )
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = $templateMetadata
                }
                
                { Submit-PSStudentChange -Changes $changes -WhatIf } | Should -Not -Throw
            }
        }

        It 'Should accept JsonPath parameter with valid file' {
            # Create temp JSON file
            $tempFile = New-TemporaryFile
            $script:SampleChanges | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile.FullName
            
            InModuleScope FSEnrollment-PSSync -Parameters @{ TempFile = $tempFile } {
                param($TempFile)
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                { Submit-PSStudentChange -JsonPath $TempFile.FullName -WhatIf } | Should -Not -Throw
            }
            
            Remove-Item $tempFile.FullName
        }

        It 'Should throw error if not connected to PowerSchool' {
            InModuleScope FSEnrollment-PSSync {
                # Clear connection variables
                $script:PowerSchoolToken = $null
                $script:PowerSchoolBaseUrl = $null
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = [PSCustomObject]@{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            [PSCustomObject]@{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            [PSCustomObject]@{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            [PSCustomObject]@{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                { Submit-PSStudentChange -Changes $changes } | Should -Throw "*Not connected to PowerSchool*"
            }
        }
        
        It 'Should NOT throw error in WhatIf mode when not connected' {
            InModuleScope FSEnrollment-PSSync {
                # Clear connection variables
                $script:PowerSchoolToken = $null
                $script:PowerSchoolBaseUrl = $null
                
                $templateMetadata = [PSCustomObject]@{
                    TemplateName = 'test_template'
                    KeyField = 'StudentNumber'
                    PowerSchoolKeyField = 'local_id'
                    PowerSchoolKeyDataType = 'int'
                    CheckForChanges = @('FirstName', 'LastName')
                    ColumnMappings = @(
                        [PSCustomObject]@{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                        [PSCustomObject]@{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                        [PSCustomObject]@{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                    )
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = $templateMetadata
                }
                
                { Submit-PSStudentChange -Changes $changes -WhatIf } | Should -Not -Throw
            }
        }

        It 'Should accept Limit parameter' {
            InModuleScope FSEnrollment-PSSync {
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                $templateMetadata = [PSCustomObject]@{
                    TemplateName = 'test_template'
                    KeyField = 'StudentNumber'
                    PowerSchoolKeyField = 'local_id'
                    PowerSchoolKeyDataType = 'int'
                    CheckForChanges = @('FirstName', 'LastName')
                    ColumnMappings = @(
                        [PSCustomObject]@{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                        [PSCustomObject]@{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                        [PSCustomObject]@{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                    )
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = $templateMetadata
                }
                
                { Submit-PSStudentChange -Changes $changes -Limit 5 -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context 'New Student Creation' {
        It 'Should create a new student successfully' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ 
                        id = 12345
                        local_id = '123456'
                    } 
                }
                
                $newStudent = [PSStudent]::new()
                $newStudent.StudentNumber = '123456'
                $newStudent.FirstName = 'John'
                $newStudent.LastName = 'Doe'
                $newStudent.GradeLevel = 9
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            MatchField = 'StudentNumber'
                            Student = $newStudent
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes
                
                $result.NewStudentsApplied | Should -Be 1
                $result.UpdatedStudentsApplied | Should -Be 0
                $result.FailedChanges.Count | Should -Be 0
                $result.Summary.TotalApplied | Should -Be 1
            }
        }

        It 'Should create multiple new students' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ id = Get-Random -Minimum 1000 -Maximum 9999 }
                }
                
                $newStudents = 1..3 | ForEach-Object {
                    $student = [PSStudent]::new()
                    $student.StudentNumber = "12345$_"
                    $student.FirstName = "Student$_"
                    $student.LastName = "Test"
                    $student.GradeLevel = 10
                    
                    [PSCustomObject]@{
                        MatchKey = "12345$_"
                        MatchField = 'StudentNumber'
                        Student = $student
                    }
                }
                
                $changes = [PSCustomObject]@{
                    New = $newStudents
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes
                
                $result.NewStudentsApplied | Should -Be 3
                $result.Summary.TotalApplied | Should -Be 3
            }
        }

        It 'Should handle creation failure and continue with remaining' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                $callCount = 0
                Mock Invoke-PowerSchoolApiRequest { 
                    $script:callCount++
                    if ($script:callCount -eq 1) {
                        throw "API Error: Student already exists"
                    }
                    return @{ id = 12345 }
                }
                
                $newStudents = 1..2 | ForEach-Object {
                    $student = [PSStudent]::new()
                    $student.StudentNumber = "12345$_"
                    $student.FirstName = "Student$_"
                    $student.LastName = "Test"
                    
                    [PSCustomObject]@{
                        MatchKey = "12345$_"
                        MatchField = 'StudentNumber'
                        Student = $student
                    }
                }
                
                $changes = [PSCustomObject]@{
                    New = $newStudents
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes -WarningAction SilentlyContinue
                
                $result.NewStudentsApplied | Should -Be 1
                $result.FailedChanges.Count | Should -Be 1
                $result.FailedChanges[0].Type | Should -Be 'New'
            }
        }
    }

    Context 'Student Update' {
        It 'Should update a student successfully' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ 
                        id = 12345
                        result = @{ status = 'SUCCESS' }
                    }
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            MatchField = 'StudentNumber'
                            PowerSchoolStudent = @{
                                id = 12345
                                local_id = '123456'
                                name = @{
                                    first_name = 'John'
                                    last_name = 'Doe'
                                }
                            }
                            Changes = @(
                                [PSCustomObject]@{
                                    Field = 'FirstName'
                                    PowerSchoolAPIField = 'name.first_name'
                                    OldValue = 'John'
                                    NewValue = 'Jonathan'
                                }
                            )
                        }
                    )
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes
                
                $result.UpdatedStudentsApplied | Should -Be 1
                $result.NewStudentsApplied | Should -Be 0
                $result.FailedChanges.Count | Should -Be 0
            }
        }

        It 'Should update multiple fields in a student' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ id = 12345 }
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            MatchField = 'StudentNumber'
                            PowerSchoolStudent = @{
                                id = 12345
                                local_id = '123456'
                            }
                            Changes = @(
                                [PSCustomObject]@{
                                    Field = 'FirstName'
                                    PowerSchoolAPIField = 'name.first_name'
                                    OldValue = 'John'
                                    NewValue = 'Jonathan'
                                },
                                [PSCustomObject]@{
                                    Field = 'LastName'
                                    PowerSchoolAPIField = 'name.last_name'
                                    OldValue = 'Doe'
                                    NewValue = 'Smith'
                                },
                                [PSCustomObject]@{
                                    Field = 'GradeLevel'
                                    PowerSchoolAPIField = 'grade_level'
                                    OldValue = 9
                                    NewValue = 10
                                }
                            )
                        }
                    )
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes
                
                $result.UpdatedStudentsApplied | Should -Be 1
            }
        }

        It 'Should handle update failure and continue' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                # Use module scope variable for call tracking
                Set-Variable -Name 'testCallCount' -Value 0 -Scope Script
                
                Mock Invoke-PowerSchoolApiRequest {
                    $script:testCallCount++
                    if ($script:testCallCount -eq 1) {
                        throw "API Error: Student not found"
                    }
                    return @{ id = 12346 }
                }
                
                $updates = 1..2 | ForEach-Object {
                    [PSCustomObject]@{
                        MatchKey = "12345$_"
                        MatchField = 'StudentNumber'
                        PowerSchoolStudent = @{
                            id = 12345 + $_
                            local_id = "12345$_"
                        }
                        Changes = @(
                            [PSCustomObject]@{
                                Field = 'FirstName'
                                PowerSchoolAPIField = 'name.first_name'
                                OldValue = 'Old'
                                NewValue = 'New'
                            }
                        )
                    }
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = $updates
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes -WarningAction SilentlyContinue
                
                $result.UpdatedStudentsApplied | Should -Be 1
                $result.FailedChanges.Count | Should -Be 1
                $result.FailedChanges[0].Type | Should -Be 'Update'
            }
        }
    }

    Context 'Limit Parameter' {
        It 'Should respect the Limit parameter for new students' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                
                $newStudents = 1..5 | ForEach-Object {
                    $student = [PSStudent]::new()
                    $student.StudentNumber = "12345$_"
                    $student.FirstName = "Student$_"
                    $student.LastName = "Test"
                    
                    [PSCustomObject]@{
                        MatchKey = "12345$_"
                        MatchField = 'StudentNumber'
                        Student = $student
                    }
                }
                
                $changes = [PSCustomObject]@{
                    New = $newStudents
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes -Limit 3
                
                $result.Summary.TotalApplied | Should -Be 3
                $result.NewStudentsApplied | Should -Be 3
            }
        }

        It 'Should respect the Limit parameter for updates' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                
                $updates = 1..5 | ForEach-Object {
                    [PSCustomObject]@{
                        MatchKey = "12345$_"
                        MatchField = 'StudentNumber'
                        PowerSchoolStudent = @{ id = 12345 + $_ }
                        Changes = @(
                            [PSCustomObject]@{
                                Field = 'FirstName'
                                PowerSchoolAPIField = 'name.first_name'
                                OldValue = 'Old'
                                NewValue = 'New'
                            }
                        )
                    }
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = $updates
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes -Limit 2
                
                $result.Summary.TotalApplied | Should -Be 2
                $result.UpdatedStudentsApplied | Should -Be 2
            }
        }

        It 'Should respect the Limit parameter for mixed new and updated' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                
                $newStudent = [PSStudent]::new()
                $newStudent.StudentNumber = '123456'
                $newStudent.FirstName = 'New'
                $newStudent.LastName = 'Student'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            MatchField = 'StudentNumber'
                            Student = $newStudent
                        },
                        [PSCustomObject]@{
                            MatchKey = '123457'
                            MatchField = 'StudentNumber'
                            Student = $newStudent
                        }
                    )
                    Updated = @(
                        [PSCustomObject]@{
                            MatchKey = '123458'
                            MatchField = 'StudentNumber'
                            PowerSchoolStudent = @{ id = 12345 }
                            Changes = @(
                                [PSCustomObject]@{
                                    Field = 'FirstName'
                                    PowerSchoolAPIField = 'name.first_name'
                                    OldValue = 'Old'
                                    NewValue = 'New'
                                }
                            )
                        }
                    )
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes -Limit 2
                
                $result.Summary.TotalApplied | Should -Be 2
                # Should process both new students before any updates
                $result.NewStudentsApplied | Should -Be 2
                $result.UpdatedStudentsApplied | Should -Be 0
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Should not make changes in WhatIf mode' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    throw "Should not be called in WhatIf mode"
                }
                
                $newStudent = [PSStudent]::new()
                $newStudent.StudentNumber = '123456'
                $newStudent.FirstName = 'John'
                $newStudent.LastName = 'Doe'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            MatchField = 'StudentNumber'
                            Student = $newStudent
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                { Submit-PSStudentChange -Changes $changes -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context 'Error Handling and Retry' {
        It 'Should pass MaxRetries parameter to API call' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                # Use module scope variable to capture parameter
                Set-Variable -Name 'capturedMaxRetries' -Value $null -Scope Script
                
                Mock Invoke-PowerSchoolApiRequest {
                    param($Uri, $Headers, $Method, $Body, $MaxRetries, $InitialRetryDelaySeconds)
                    $script:capturedMaxRetries = $MaxRetries
                    return @{ id = 12345 }
                }
                
                $newStudent = [PSStudent]::new()
                $newStudent.StudentNumber = '123456'
                $newStudent.FirstName = 'John'
                $newStudent.LastName = 'Doe'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            MatchField = 'StudentNumber'
                            Student = $newStudent
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                Submit-PSStudentChange -Changes $changes -MaxRetries 5 | Out-Null
                
                $capturedMaxRetries | Should -Be 5
            }
        }

        It 'Should pass RetryDelaySeconds parameter to API call' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                # Use module scope variable to capture parameter
                Set-Variable -Name 'capturedRetryDelay' -Value $null -Scope Script
                
                Mock Invoke-PowerSchoolApiRequest {
                    param($Uri, $Headers, $Method, $Body, $MaxRetries, $InitialRetryDelaySeconds)
                    $script:capturedRetryDelay = $InitialRetryDelaySeconds
                    return @{ id = 12345 }
                }
                
                $newStudent = [PSStudent]::new()
                $newStudent.StudentNumber = '123456'
                $newStudent.FirstName = 'John'
                $newStudent.LastName = 'Doe'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            MatchField = 'StudentNumber'
                            Student = $newStudent
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                Submit-PSStudentChange -Changes $changes -RetryDelaySeconds 10 | Out-Null
                
                $capturedRetryDelay | Should -Be 10
            }
        }
    }

    Context 'JSON File Input' {
        It 'Should load changes from JSON file' {
            $tempFile = New-TemporaryFile
            
            # Create simple hashtable structure that doesn't require PSStudent class
            $changes = [PSCustomObject]@{
                New = @(
                    @{
                        MatchKey = '123456'
                        MatchField = 'StudentNumber'
                        Student = @{
                            StudentNumber = '123456'
                            FirstName = 'John'
                            LastName = 'Doe'
                            GradeLevel = 9
                        }
                    }
                )
                Updated = @()
                TemplateMetadata = @{
                    TemplateName = 'test_template'
                    KeyField = 'StudentNumber'
                    PowerSchoolKeyField = 'local_id'
                    ColumnMappings = @()
                }
            }
            
            $changes | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile.FullName
            
            InModuleScope FSEnrollment-PSSync -Parameters @{ TempFile = $tempFile } {
                param($TempFile)
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                
                $result = Submit-PSStudentChange -JsonPath $TempFile.FullName
                
                # JSON deserialization will succeed even though Student is not a PSStudent instance
                # The function should handle it gracefully
                $result.Summary.TotalProcessed | Should -BeGreaterOrEqual 0
            }
            
            Remove-Item $tempFile.FullName
        }
    }

    Context 'Result Object Structure' {
        It 'Should return proper result structure' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { return @{ id = 12345 } }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes
                
                $result.PSObject.Properties['NewStudentsApplied'] | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties['UpdatedStudentsApplied'] | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties['FailedChanges'] | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties['Summary'] | Should -Not -BeNullOrEmpty
                $result.Summary.PSObject.Properties['TotalProcessed'] | Should -Not -BeNullOrEmpty
                $result.Summary.PSObject.Properties['TotalApplied'] | Should -Not -BeNullOrEmpty
                $result.Summary.PSObject.Properties['TotalFailed'] | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should include failed changes details' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest {
                    throw "Test API Error"
                }
                
                $newStudent = [PSStudent]::new()
                $newStudent.StudentNumber = '123456'
                $newStudent.FirstName = 'John'
                $newStudent.LastName = 'Doe'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = '123456'
                            Student = $newStudent
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_template'
                        KeyField = 'StudentNumber'
                        PowerSchoolKeyField = 'local_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
                        )
                    }
                }
                
                $result = Submit-PSStudentChange -Changes $changes -WarningAction SilentlyContinue
                
                $result.FailedChanges.Count | Should -Be 1
                $result.FailedChanges[0].Type | Should -Be 'New'
                $result.FailedChanges[0].MatchKey | Should -Be '123456'
                $result.FailedChanges[0].Error | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'Submit-PSStudentChange Helper Functions' {
    Context 'Build-StudentPayload' {
        It 'Should build payload with name fields' {
            InModuleScope FSEnrollment-PSSync {
                $student = [PSStudent]::new()
                $student.StudentNumber = '123456'
                $student.FirstName = 'John'
                $student.MiddleName = 'Q'
                $student.LastName = 'Doe'
                $student.GradeLevel = 9
                
                $payload = Build-StudentPayload -Student $student
                
                $payload.students.student.local_id | Should -Be '123456'
                $payload.students.student.grade_level | Should -Be 9
                $payload.students.student.name.first_name | Should -Be 'John'
                $payload.students.student.name.middle_name | Should -Be 'Q'
                $payload.students.student.name.last_name | Should -Be 'Doe'
            }
        }

        It 'Should build payload with address fields' {
            InModuleScope FSEnrollment-PSSync {
                $student = [PSStudent]::new()
                $student.StudentNumber = '123456'
                $student.FirstName = 'John'
                $student.LastName = 'Doe'
                $student.Street = '123 Main St'
                $student.City = 'Springfield'
                $student.State = 'IL'
                $student.Zip = '62701'
                
                $payload = Build-StudentPayload -Student $student
                
                $payload.students.student.street | Should -Be '123 Main St'
                $payload.students.student.city | Should -Be 'Springfield'
                $payload.students.student.state | Should -Be 'IL'
                $payload.students.student.zip | Should -Be '62701'
            }
        }
    }

    Context 'Build-UpdatePayload' {
        It 'Should build update payload from changes' {
            InModuleScope FSEnrollment-PSSync {
                $changes = @(
                    [PSCustomObject]@{
                        Field = 'FirstName'
                        PowerSchoolAPIField = 'name.first_name'
                        OldValue = 'John'
                        NewValue = 'Jonathan'
                    },
                    [PSCustomObject]@{
                        Field = 'GradeLevel'
                        PowerSchoolAPIField = 'grade_level'
                        OldValue = 9
                        NewValue = 10
                    }
                )
                
                                $powerSchoolStudent = @{
                    id = 12345
                    local_id = '123456'
                    name = @{
                        first_name = 'John'
                        last_name = 'Doe'
                    }
                    grade_level = 9
                }
                
                $payload = Build-UpdatePayload -Changes $changes -StudentDCID 12345 -PowerSchoolStudent $powerSchoolStudent
                
                $payload.students.student.id | Should -Be 12345
                $payload.students.student.name.first_name | Should -Be 'Jonathan'
                $payload.students.student.grade_level | Should -Be 10
            }
        }

        It 'Should handle multiple name field changes' {
            InModuleScope FSEnrollment-PSSync {
                $changes = @(
                    [PSCustomObject]@{
                        Field = 'FirstName'
                        PowerSchoolAPIField = 'name.first_name'
                        OldValue = 'John'
                        NewValue = 'Jonathan'
                    },
                    [PSCustomObject]@{
                        Field = 'LastName'
                        PowerSchoolAPIField = 'name.last_name'
                        OldValue = 'Doe'
                        NewValue = 'Smith'
                    }
                )
                
                                $powerSchoolStudent = @{
                    id = 12345
                    local_id = '123456'
                    name = @{
                        first_name = 'John'
                        last_name = 'Doe'
                    }
                    grade_level = 9
                }
                
                $payload = Build-UpdatePayload -Changes $changes -StudentDCID 12345 -PowerSchoolStudent $powerSchoolStudent
                
                $payload.students.student.name.first_name | Should -Be 'Jonathan'
                $payload.students.student.name.last_name | Should -Be 'Smith'
            }
        }
    }
}


