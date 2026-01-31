#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    $ModulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module "$ModulePath/FSEnrollment-PSSync.psd1" -Force
}

Describe 'Invoke-PSRequest' {
    Context 'Parameter Validation' {
        It 'Should have Endpoint as a mandatory parameter' {
            (Get-Command Invoke-PSRequest).Parameters['Endpoint'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have Method as an optional parameter with default value Get' {
            $command = Get-Command Invoke-PSRequest
            $command.Parameters['Method'].Attributes.Mandatory | Should -Be $false
            $command.Parameters['Method'].ParameterType.Name | Should -Be 'String'
        }

        It 'Should validate Method parameter values' {
            $command = Get-Command Invoke-PSRequest
            $validateSet = $command.Parameters['Method'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Get'
            $validateSet.ValidValues | Should -Contain 'Post'
            $validateSet.ValidValues | Should -Contain 'Put'
            $validateSet.ValidValues | Should -Contain 'Patch'
            $validateSet.ValidValues | Should -Contain 'Delete'
        }

        It 'Should have Body as an optional parameter' {
            (Get-Command Invoke-PSRequest).Parameters['Body'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should have MaxRetries as an optional parameter' {
            (Get-Command Invoke-PSRequest).Parameters['MaxRetries'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should have InitialRetryDelaySeconds as an optional parameter' {
            (Get-Command Invoke-PSRequest).Parameters['InitialRetryDelaySeconds'].Attributes.Mandatory | Should -Be $false
        }
    }

    Context 'GET Requests' {
        BeforeAll {
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
                $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token' -AsPlainText -Force
                $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
            }
        }

        It 'Should make a GET request to the specified endpoint' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ success = $true; data = @{ id = 1234 } }
                } -ParameterFilter { $Method -eq 'Get' }

                $result = Invoke-PSRequest -Endpoint '/ws/v1/student/1234'

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://test.powerschool.com/ws/v1/student/1234' -and
                    $Method -eq 'Get' -and
                    $Headers['Authorization'] -eq 'Bearer test-token'
                }
                $result.success | Should -Be $true
            }
        }

        It 'Should normalize endpoint by removing leading slash' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint 'ws/contacts/contact/5678'

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://test.powerschool.com/ws/contacts/contact/5678'
                }
            }
        }

        It 'Should handle endpoint with leading slash' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint '/ws/contacts/contact/5678'

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://test.powerschool.com/ws/contacts/contact/5678'
                }
            }
        }
    }

    Context 'POST Requests' {
        BeforeAll {
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
                $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token' -AsPlainText -Force
                $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
            }
        }

        It 'Should make a POST request with body' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ id = 9999; success = $true }
                } -ParameterFilter { $Method -eq 'Post' }

                $body = @{
                    name = @{
                        first_name = 'John'
                        last_name = 'Doe'
                    }
                }
                $result = Invoke-PSRequest -Endpoint '/ws/contacts/contact' -Method Post -Body $body

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://test.powerschool.com/ws/contacts/contact' -and
                    $Method -eq 'Post' -and
                    $Body -ne $null
                }
                $result.success | Should -Be $true
            }
        }
    }

    Context 'PUT/PATCH Requests' {
        BeforeAll {
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
                $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token' -AsPlainText -Force
                $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
            }
        }

        It 'Should make a PATCH request with body' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ success = $true; updated = $true }
                } -ParameterFilter { $Method -eq 'Patch' }

                $updates = @{
                    contact_info = @{
                        email = 'newemail@example.com'
                    }
                }
                $result = Invoke-PSRequest -Endpoint '/ws/contacts/contact/5678' -Method Patch -Body $updates

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://test.powerschool.com/ws/contacts/contact/5678' -and
                    $Method -eq 'Patch' -and
                    $Body -ne $null
                }
                $result.success | Should -Be $true
            }
        }

        It 'Should make a PUT request with body' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ success = $true; replaced = $true }
                } -ParameterFilter { $Method -eq 'Put' }

                $data = @{
                    name = @{ first_name = 'Jane'; last_name = 'Smith' }
                }
                $result = Invoke-PSRequest -Endpoint '/ws/contacts/contact/5678' -Method Put -Body $data

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://test.powerschool.com/ws/contacts/contact/5678' -and
                    $Method -eq 'Put'
                }
                $result.success | Should -Be $true
            }
        }
    }

    Context 'DELETE Requests' {
        BeforeAll {
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
                $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token' -AsPlainText -Force
                $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
            }
        }

        It 'Should make a DELETE request' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ success = $true; deleted = $true }
                } -ParameterFilter { $Method -eq 'Delete' }

                $result = Invoke-PSRequest -Endpoint '/ws/contacts/contact/5678' -Method Delete

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://test.powerschool.com/ws/contacts/contact/5678' -and
                    $Method -eq 'Delete'
                }
                $result.success | Should -Be $true
            }
        }
    }

    Context 'Retry Logic' {
        BeforeAll {
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
                $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token' -AsPlainText -Force
                $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
            }
        }

        It 'Should pass custom MaxRetries to the API request function' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint '/ws/v1/student/1234' -MaxRetries 5

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $MaxRetries -eq 5
                }
            }
        }

        It 'Should pass custom InitialRetryDelaySeconds to the API request function' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint '/ws/v1/student/1234' -InitialRetryDelaySeconds 10

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $InitialRetryDelaySeconds -eq 10
                }
            }
        }
    }

    Context 'Authorization Handling' {
        BeforeAll {
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
                $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token' -AsPlainText -Force
                $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
            }
        }

        It 'Should validate connection before making request' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint '/ws/v1/student/1234'

                Should -Invoke Test-PowerSchoolConnection -Times 1 -Exactly
            }
        }

        It 'Should get access token before making request' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint '/ws/v1/student/1234'

                Should -Invoke Get-PowerSchoolAccessToken -Times 1 -Exactly
            }
        }

        It 'Should include Authorization header with Bearer token' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'my-secure-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint '/ws/v1/student/1234'

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Headers['Authorization'] -eq 'Bearer my-secure-token'
                }
            }
        }

        It 'Should include Content-Type and Accept headers' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                Invoke-PSRequest -Endpoint '/ws/v1/student/1234'

                Should -Invoke Invoke-PowerSchoolApiRequest -Times 1 -Exactly -ParameterFilter {
                    $Headers['Content-Type'] -eq 'application/json' -and
                    $Headers['Accept'] -eq 'application/json'
                }
            }
        }
    }

    Context 'Error Handling' {
        BeforeAll {
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
                $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token' -AsPlainText -Force
                $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
            }
        }

        It 'Should throw error when API request fails' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { throw 'API Error' }

                { Invoke-PSRequest -Endpoint '/ws/v1/student/1234' } | Should -Throw
            }
        }

        It 'Should throw error when connection test fails' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { throw 'Not connected' }
                Mock Get-PowerSchoolAccessToken { return 'test-token' }
                Mock Invoke-PowerSchoolApiRequest { return @{ success = $true } }

                { Invoke-PSRequest -Endpoint '/ws/v1/student/1234' } | Should -Throw
            }
        }
    }
}
