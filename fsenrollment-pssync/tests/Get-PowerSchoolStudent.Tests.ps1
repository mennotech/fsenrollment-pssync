#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Get-PowerSchoolStudent' {
    BeforeEach {
        # Mock connection state
        Mock Test-PowerSchoolConnection { }
        Mock Get-PowerSchoolAccessToken { return 'mock-token-123' }
        
        # Set up script variables to simulate connected state
        InModuleScope FSEnrollment-PSSync {
            $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
        }
    }

    Context 'Parameter Sets' {
        It 'Should accept StudentId parameter' {
            Mock Invoke-PowerSchoolApiRequest {
                return @{
                    student = @{
                        id = 12345
                        student_number = '123456'
                        first_name = 'John'
                        last_name = 'Doe'
                    }
                }
            }

            $result = Get-PowerSchoolStudent -StudentId 12345
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be 12345
        }

        It 'Should accept StudentNumber parameter' {
            Mock Invoke-PowerSchoolApiRequest {
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
            Mock Invoke-PowerSchoolApiRequest {
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
        It 'Should construct correct endpoint for StudentId' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Be 'https://test.powerschool.com/ws/v1/student/12345'
                return @{ student = @{ id = 12345 } }
            }

            Get-PowerSchoolStudent -StudentId 12345
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should include expansions in query string for StudentId' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'expansions=demographics,addresses'
                return @{ student = @{ id = 12345 } }
            }

            Get-PowerSchoolStudent -StudentId 12345 -Expansions @('demographics', 'addresses')
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should construct query for StudentNumber lookup' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'q=student_number==123456'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -StudentNumber '123456'
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should construct district/student endpoint for All' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match '/ws/v1/district/student\?'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }
    }

    Context 'Pagination' {
        It 'Should use default PageSize of 100 for All' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'pagesize=100'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should use custom PageSize when provided' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Uri)
                $Uri | Should -Match 'pagesize=50'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All -PageSize 50
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should handle multiple pages of results' {
            $callCount = 0
            Mock Invoke-PowerSchoolApiRequest {
                $callCount++
                if ($callCount -eq 1) {
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

        It 'Should stop pagination when page is not full' {
            Mock Invoke-PowerSchoolApiRequest {
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
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should handle single student response as array' {
            Mock Invoke-PowerSchoolApiRequest {
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
            Mock Test-PowerSchoolConnection { }
            Mock Invoke-PowerSchoolApiRequest {
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke Test-PowerSchoolConnection -Times 1
        }

        It 'Should retrieve access token for API request' {
            Mock Get-PowerSchoolAccessToken { return 'test-token' }
            Mock Invoke-PowerSchoolApiRequest {
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke Get-PowerSchoolAccessToken -Times 1
        }
    }

    Context 'Headers' {
        It 'Should include Bearer token in Authorization header' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Headers)
                $Headers['Authorization'] | Should -Be 'Bearer mock-token-123'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }

        It 'Should include correct Content-Type and Accept headers' {
            Mock Invoke-PowerSchoolApiRequest {
                param($Headers)
                $Headers['Content-Type'] | Should -Be 'application/json'
                $Headers['Accept'] | Should -Be 'application/json'
                return @{ students = @{ student = @() } }
            }

            Get-PowerSchoolStudent -All
            Should -Invoke Invoke-PowerSchoolApiRequest -Times 1
        }
    }

    Context 'Error Handling' {
        It 'Should throw error on API failure' {
            Mock Invoke-PowerSchoolApiRequest {
                throw "API Error: Not Found"
            }

            { Get-PowerSchoolStudent -StudentId 99999 -ErrorAction Stop } | Should -Throw
        }
    }
}
