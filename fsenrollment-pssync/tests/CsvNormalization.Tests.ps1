#Requires -Version 7.0

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $PublicPath = Join-Path $ModuleRoot 'public'
    
    . (Join-Path $PublicPath 'Get-CsvNormalizationTemplate.ps1')
    . (Join-Path $PublicPath 'ConvertTo-NormalizedData.ps1')
}

Describe 'Get-CsvNormalizationTemplate' {
    Context 'When loading the default template' {
        It 'Should load the fs_powerschool_nonapi_report template' {
            $template = Get-CsvNormalizationTemplate
            $template | Should -Not -BeNullOrEmpty
            $template.Name | Should -Be 'fs_powerschool_nonapi_report'
        }

        It 'Should return a hashtable' {
            $template = Get-CsvNormalizationTemplate
            $template | Should -BeOfType [hashtable]
        }

        It 'Should contain required keys' {
            $template = Get-CsvNormalizationTemplate
            $template.ContainsKey('Name') | Should -Be $true
            $template.ContainsKey('Version') | Should -Be $true
            $template.ContainsKey('Students') | Should -Be $true
            $template.ContainsKey('Parents') | Should -Be $true
        }

        It 'Should contain supported types' {
            $template = Get-CsvNormalizationTemplate
            $template.SupportedTypes | Should -Contain 'students'
            $template.SupportedTypes | Should -Contain 'parents'
            $template.SupportedTypes | Should -Contain 'staff'
        }
    }

    Context 'When loading a non-existent template' {
        It 'Should throw an error' {
            { Get-CsvNormalizationTemplate -TemplateName 'nonexistent' } | Should -Throw
        }
    }

    Context 'When loading template with verbose output' {
        It 'Should output verbose messages' {
            $verboseOutput = Get-CsvNormalizationTemplate -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'ConvertTo-NormalizedData' {
    BeforeAll {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $StudentsPath = Join-Path $RepoRoot 'data/examples/students_example.csv'
        $ParentsPath = Join-Path $RepoRoot 'data/examples/parents_example.csv'
        
        $testStudents = @(
            [PSCustomObject]@{
                Student_Number = '12345'
                First_Name = 'John'
                Last_Name = 'Doe'
                Grade_Level = '10'
                SchoolID = '100'
                Gender = 'M'
                DOB = '01/15/2010'
                Enroll_Status = '0'
            }
        )

        $testParents = @(
            [PSCustomObject]@{
                'New Contact Identifier' = 'test-guid-123'
                'First Name' = 'Jane'
                'Last Name' = 'Doe'
                'Email Address' = 'jane.doe@example.com'
                'Is Active' = '1'
                'studentNumber' = '12345'
                'Relationship Type' = 'Mother'
            }
        )
    }

    Context 'When normalizing student data' {
        It 'Should normalize student records' {
            $normalized = ConvertTo-NormalizedData -CsvData $testStudents -DataType 'students'
            $normalized | Should -Not -BeNullOrEmpty
            $normalized.Count | Should -Be 1
        }

        It 'Should map student_number correctly' {
            $normalized = ConvertTo-NormalizedData -CsvData $testStudents -DataType 'students'
            $normalized[0].student_number | Should -Be '12345'
        }

        It 'Should map first_name correctly' {
            $normalized = ConvertTo-NormalizedData -CsvData $testStudents -DataType 'students'
            $normalized[0].first_name | Should -Be 'John'
        }

        It 'Should map last_name correctly' {
            $normalized = ConvertTo-NormalizedData -CsvData $testStudents -DataType 'students'
            $normalized[0].last_name | Should -Be 'Doe'
        }

        It 'Should convert grade_level to integer' {
            $normalized = ConvertTo-NormalizedData -CsvData $testStudents -DataType 'students'
            $normalized[0].grade_level | Should -Be 10
            $normalized[0].grade_level | Should -BeOfType [int]
        }

        It 'Should convert school_id to integer' {
            $normalized = ConvertTo-NormalizedData -CsvData $testStudents -DataType 'students'
            $normalized[0].school_id | Should -Be 100
            $normalized[0].school_id | Should -BeOfType [int]
        }
    }

    Context 'When normalizing parent data' {
        It 'Should normalize parent records' {
            $normalized = ConvertTo-NormalizedData -CsvData $testParents -DataType 'parents'
            $normalized | Should -Not -BeNullOrEmpty
            $normalized.Count | Should -Be 1
        }

        It 'Should map id correctly' {
            $normalized = ConvertTo-NormalizedData -CsvData $testParents -DataType 'parents'
            $normalized[0].id | Should -Be 'test-guid-123'
        }

        It 'Should map email correctly' {
            $normalized = ConvertTo-NormalizedData -CsvData $testParents -DataType 'parents'
            $normalized[0].email | Should -Be 'jane.doe@example.com'
        }

        It 'Should convert is_active to boolean' {
            $normalized = ConvertTo-NormalizedData -CsvData $testParents -DataType 'parents'
            $normalized[0].is_active | Should -Be $true
            $normalized[0].is_active | Should -BeOfType [bool]
        }

        It 'Should map student_number correctly' {
            $normalized = ConvertTo-NormalizedData -CsvData $testParents -DataType 'parents'
            $normalized[0].student_number | Should -Be '12345'
        }
    }

    Context 'When normalizing with real example files' {
        It 'Should normalize students_example.csv if it exists' {
            if (Test-Path $StudentsPath) {
                $students = Import-Csv $StudentsPath
                $normalized = ConvertTo-NormalizedData -CsvData $students -DataType 'students'
                $normalized | Should -Not -BeNullOrEmpty
                $normalized.Count | Should -BeGreaterThan 0
            }
        }

        It 'Should normalize parents_example.csv if it exists' {
            if (Test-Path $ParentsPath) {
                $parents = Import-Csv $ParentsPath
                $normalized = ConvertTo-NormalizedData -CsvData $parents -DataType 'parents'
                $normalized | Should -Not -BeNullOrEmpty
                $normalized.Count | Should -BeGreaterThan 0
            }
        }
    }

    Context 'When handling invalid data types' {
        It 'Should throw error for unsupported data type' {
            { ConvertTo-NormalizedData -CsvData $testStudents -DataType 'invalid' } | Should -Throw
        }
    }

    Context 'When using custom template' {
        It 'Should accept custom template parameter' {
            $template = Get-CsvNormalizationTemplate
            $normalized = ConvertTo-NormalizedData -CsvData $testStudents -DataType 'students' -Template $template
            $normalized | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When handling empty CSV data' {
        It 'Should require non-empty CsvData parameter' {
            { ConvertTo-NormalizedData -CsvData @() -DataType 'students' } | Should -Throw
        }
    }

    Context 'When using SkipValidation switch' {
        It 'Should skip validation when requested' {
            $incompleteData = @(
                [PSCustomObject]@{
                    First_Name = 'John'
                }
            )
            $normalized = ConvertTo-NormalizedData -CsvData $incompleteData -DataType 'students' -SkipValidation
            $normalized | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'CSV Normalization Integration Tests' {
    BeforeAll {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $StudentsPath = Join-Path $RepoRoot 'data/examples/students_example.csv'
    }

    Context 'End-to-end normalization workflow' {
        It 'Should load template, import CSV, and normalize data' {
            if (Test-Path $StudentsPath) {
                $template = Get-CsvNormalizationTemplate
                $students = Import-Csv $StudentsPath
                $normalized = ConvertTo-NormalizedData -CsvData $students -DataType 'students' -Template $template
                
                $normalized | Should -Not -BeNullOrEmpty
                $normalized[0].PSObject.Properties.Name | Should -Contain 'student_number'
                $normalized[0].PSObject.Properties.Name | Should -Contain 'first_name'
                $normalized[0].PSObject.Properties.Name | Should -Contain 'last_name'
            }
        }
    }
}
