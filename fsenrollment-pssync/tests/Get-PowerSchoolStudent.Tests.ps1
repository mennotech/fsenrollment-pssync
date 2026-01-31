#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Get-PowerSchoolStudent' {
    BeforeEach {
        # Mock connection state at module level
        Mock -ModuleName FSEnrollment-PSSync Test-PowerSchoolConnection { }
        Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token-123' }
        
        # Set up script variables to simulate connected state
        InModuleScope FSEnrollment-PSSync {
            $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
        }
    }

    Context 'Parameter Sets' {
        It 'Should accept DCID parameter' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{
                    student = @{
                        id = 12345
                        local_id = '123456'
                        first_name = 'John'
                        last_name = 'Doe'
                    }
                }
            }

            $result = Get-PowerSchoolStudent -DCID 12345
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be 12345
        }

        It 'Should accept StudentNumber parameter' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{
                    students = @{
                        student = @(
                            @{
                                id = 12345
                                student_number = '123456'
                                first_name = 'John'
                                last_name = 'Doe'
                            }
                        )
                    }
                }
            }

            $result = Get-PowerSchoolStudent -StudentNumber '123456'
            $result | Should -Not -BeNullOrEmpty
            $result.student_number | Should -Be '123456'
        }

        It 'Should accept All switch parameter' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{
                    students = @{
                        student = @(
                            @{
                                id = 1
                                student_number = '111'
                                first_name = 'Student'
                                last_name = 'One'
                            },
                            @{
                                id = 2
                                student_number = '222'
                                first_name = 'Student'
                                last_name = 'Two'
                            }
                        )
                    }
                }
            }

            $result = Get-PowerSchoolStudent -All
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
    }

    Context 'API Endpoint Construction' {
        It 'Should construct correct endpoint for DCID' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Be 'https://test.powerschool.com/ws/v1/student/12345'
                return @{ student = @{ id = 12345 } }
            }

            Get-PowerSchoolStudent -DCID 12345
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should include expansions in query string for DCID' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'expansions=demographics,addresses'
                return @{ student = @{ id = 12345 } }
            }

            Get-PowerSchoolStudent -DCID 12345 -Expansions @('demographics', 'addresses')
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should construct query for StudentNumber lookup' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'q=local_id==123456'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -StudentNumber '123456'
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should construct district/student endpoint for All' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match '/ws/v1/district/student\?'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }
    }

    Context 'Pagination' {
        It 'Should use default PageSize of 100 for All' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'pagesize=100'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should use custom PageSize when provided' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'pagesize=50'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All -PageSize 50
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should handle multiple pages of results' {
            InModuleScope FSEnrollment-PSSync {
                # Use script scope within module to track call count
                $script:testCallCount = 0
                
                Mock Invoke-PowerSchoolApiRequest {
                    $script:testCallCount++
                    if ($script:testCallCount -eq 1) {
                        # First page - full page
                        return @{
                            students = @{
                                student = @(1..10 | ForEach-Object {
                                    @{ id = $_; student_number = "$_" }
                                })
                            }
                        }
                    } else {
                        # Second page - partial page (signals end)
                        return @{
                            students = @{
                                student = @(
                                    @{ id = 11; student_number = '11' }
                                )
                            }
                        }
                    }
                }

                $result = Get-PowerSchoolStudent -All -PageSize 10
                $result.Count | Should -Be 11
                Should -Invoke Invoke-PowerSchoolApiRequest -Times 2
            }
        }

        It 'Should stop pagination when page is not full' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{
                    students = @{
                        student = @(1..5 | ForEach-Object {
                            @{ id = $_; student_number = "$_" }
                        })
                    }
                }
            }

            $result = Get-PowerSchoolStudent -All -PageSize 10
            $result.Count | Should -Be 5
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should handle single student response as array' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{
                    students = @{
                        student = @{
                            id = 1
                            student_number = '1'
                        }
                    }
                }
            }

            $result = Get-PowerSchoolStudent -All -PageSize 10
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
        }
    }

    Context 'Connection Validation' {
        It 'Should call Test-PowerSchoolConnection before making API request' {
            Mock -ModuleName FSEnrollment-PSSync Test-PowerSchoolConnection { }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke -ModuleName FSEnrollment-PSSync Test-PowerSchoolConnection -Times 1
        }

        It 'Should retrieve access token for API request' {
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'test-token' }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken -Times 1
        }
    }

    Context 'Headers' {
        It 'Should include Bearer token in Authorization header' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Headers)
                $Headers['Authorization'] | Should -Be 'Bearer mock-token-123'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should include correct Content-Type and Accept headers' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Headers)
                $Headers['Content-Type'] | Should -Be 'application/json'
                $Headers['Accept'] | Should -Be 'application/json'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest -Times 1
        }
    }

    Context 'Template-Based Auto-Detection' {
        It 'Should auto-detect expansions from TemplateMetadata' {
            Mock -ModuleName FSEnrollment-PSSync Get-RequiredPowerSchoolFields {
                return [PSCustomObject]@{
                    Extensions = @()
                    Expansions = @('demographics', 'addresses')
                }
            }

            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'expansions=demographics,addresses|expansions=addresses,demographics'
                return @{ students = @{ student = @() } }
            }

            $templateMetadata = @{ ColumnMappings = @() }
            Get-PowerSchoolStudent -All -TemplateMetadata $templateMetadata
            
            Should -Invoke -ModuleName FSEnrollment-PSSync Get-RequiredPowerSchoolFields -Times 1
        }

        It 'Should auto-detect extensions from TemplateMetadata' {
            Mock -ModuleName FSEnrollment-PSSync Get-RequiredPowerSchoolFields {
                return [PSCustomObject]@{
                    Extensions = @('u_students_extension')
                    Expansions = @()
                }
            }

            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'extensions=u_students_extension'
                return @{ students = @{ student = @() } }
            }

            $templateMetadata = @{ ColumnMappings = @() }
            Get-PowerSchoolStudent -All -TemplateMetadata $templateMetadata
            
            Should -Invoke -ModuleName FSEnrollment-PSSync Get-RequiredPowerSchoolFields -Times 1
        }

        It 'Should load template and auto-detect when using TemplateName' {
            # Create a temporary test template file
            $tempTemplatePath = Join-Path $TestDrive 'test_template.psd1'
            $tempTemplateContent = @'
@{
    TemplateName = 'test_template'
    EntityType = 'PSStudent'
    ColumnMappings = @(
        @{ CSVColumn = 'DOB'; EntityProperty = 'DOB'; DataType = 'datetime'; PowerSchoolAPIField = '@demographics.birth_date' }
    )
}
'@
            $tempTemplateContent | Out-File -FilePath $tempTemplatePath -Encoding UTF8

            Mock -ModuleName FSEnrollment-PSSync Get-RequiredPowerSchoolFields {
                return [PSCustomObject]@{
                    Extensions = @()
                    Expansions = @('demographics')
                }
            }

            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                return @{ students = @{ student = @() } }
            }

            InModuleScope FSEnrollment-PSSync {
                param($TemplatePath)
                # Override the template path resolution
                Mock Join-Path {
                    param($Path, $ChildPath)
                    if ($ChildPath -match 'test_template\.psd1$') {
                        return $TemplatePath
                    }
                    return (Microsoft.PowerShell.Management\Join-Path $Path $ChildPath)
                }
                
                Get-PowerSchoolStudent -All -TemplateName 'test_template'
                
                Should -Invoke Get-RequiredPowerSchoolFields -Times 1
            } -ArgumentList $tempTemplatePath
        }

        It 'Should merge manual expansions with auto-detected ones' {
            Mock -ModuleName FSEnrollment-PSSync Get-RequiredPowerSchoolFields {
                return [PSCustomObject]@{
                    Extensions = @()
                    Expansions = @('demographics')
                }
            }

            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                # Should include both demographics (auto) and phones (manual)
                $Uri | Should -Match 'demographics'
                $Uri | Should -Match 'phones'
                return @{ students = @{ student = @() } }
            }

            $templateMetadata = @{ ColumnMappings = @() }
            Get-PowerSchoolStudent -All -TemplateMetadata $templateMetadata -Expansions @('phones')
        }

        It 'Should not duplicate expansions when merging' {
            Mock -ModuleName FSEnrollment-PSSync Get-RequiredPowerSchoolFields {
                return [PSCustomObject]@{
                    Extensions = @()
                    Expansions = @('demographics', 'addresses')
                }
            }

            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                param($Uri)
                # Verify demographics appears only once
                $matches = [regex]::Matches($Uri, 'demographics')
                $matches.Count | Should -Be 1
                return @{ students = @{ student = @() } }
            }

            $templateMetadata = @{ ColumnMappings = @() }
            Get-PowerSchoolStudent -All -TemplateMetadata $templateMetadata -Expansions @('demographics')
        }

        It 'Should throw error when TemplateName file not found' {
            InModuleScope FSEnrollment-PSSync {
                Mock Import-PowerShellDataFile {
                    throw "File not found"
                }
                
                { Get-PowerSchoolStudent -All -TemplateName 'nonexistent_template' -ErrorAction Stop } | Should -Throw
            }
        }
    }

    Context 'Error Handling' {
        It 'Should throw error on API failure' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerSchoolApiRequest {
                throw "API Error: Not Found"
            }

            { Get-PowerSchoolStudent -DCID 99999 -ErrorAction Stop } | Should -Throw
        }
    }
}

