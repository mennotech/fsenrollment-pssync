#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Connect-PowerSchool' {
    BeforeEach {
        # Clear any existing connection
        if (Get-Variable -Name PowerSchoolToken -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name PowerSchoolToken -Scope Script -Force
        }
        if (Get-Variable -Name PowerSchoolTokenExpiry -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name PowerSchoolTokenExpiry -Scope Script -Force
        }
        if (Get-Variable -Name PowerSchoolBaseUrl -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name PowerSchoolBaseUrl -Scope Script -Force
        }
        if (Get-Variable -Name PowerSchoolClientId -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name PowerSchoolClientId -Scope Script -Force
        }
        if (Get-Variable -Name PowerSchoolClientSecret -Scope Script -ErrorAction SilentlyContinue) {
            Remove-Variable -Name PowerSchoolClientSecret -Scope Script -Force
        }
    }

    Context 'Parameter Validation' {
        BeforeEach {
            # Mock Invoke-RestMethod in the module scope
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                return @{
                    access_token = 'test-token-123'
                    expires_in = 3600
                }
            }
        }

        It 'Should accept BaseUrl parameter' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force

            { Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should normalize BaseUrl by removing trailing slash' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force

            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com/' -ClientId 'test-client' -ClientSecret $testSecret
            
            # Verify the script variable was set correctly
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolBaseUrl | Should -Be 'https://test.powerschool.com'
            }
        }
    }

    Context 'OAuth Authentication' {
        BeforeEach {
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                return @{
                    access_token = 'test-token-123'
                    expires_in = 3600
                }
            }
        }

        It 'Should send correct OAuth request with Basic Auth' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force

            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret
            
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-RestMethod -Times 1 -ParameterFilter {
                $Uri -match '/oauth/access_token/' -and
                $Method -eq 'Post' -and
                $Headers['Content-Type'] -eq 'application/x-www-form-urlencoded' -and
                $Headers['Authorization'] -match '^Basic ' -and
                $Body -eq 'grant_type=client_credentials'
            }
        }

        It 'Should handle token expiry from response' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force
            
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                return @{
                    access_token = 'test-token-123'
                    expires_in = 7200
                }
            }

            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret
            
            # Token expiry should be set approximately 7200 seconds in the future
            # We'll test with a 10-second tolerance
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolTokenExpiry | Should -BeGreaterThan (Get-Date).AddSeconds(7190)
                $script:PowerSchoolTokenExpiry | Should -BeLessThan (Get-Date).AddSeconds(7210)
            }
        }

        It 'Should default to 3600 seconds if expires_in not provided' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force
            
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                return @{
                    access_token = 'test-token-123'
                }
            }

            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret
            
            # Token expiry should be set approximately 3600 seconds in the future
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolTokenExpiry | Should -BeGreaterThan (Get-Date).AddSeconds(3590)
                $script:PowerSchoolTokenExpiry | Should -BeLessThan (Get-Date).AddSeconds(3610)
            }
        }

        It 'Should throw error on failed authentication' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force
            
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                throw "Unauthorized: Invalid credentials"
            }

            { Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Environment Variable Support' {
        BeforeEach {
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                return @{
                    access_token = 'test-token-123'
                    expires_in = 3600
                }
            }
        }

        It 'Should use environment variables if parameters not provided' {
            $env:PowerSchool_BaseUrl = 'https://env.powerschool.com'
            $env:PowerSchool_ClientID = 'env-client-id'
            $env:PowerSchool_ClientSecret = 'env-secret'

            try {
                Connect-PowerSchool
                Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-RestMethod -Times 1 -ParameterFilter {
                    $Uri -match 'env\.powerschool\.com'
                }
            }
            finally {
                Remove-Item Env:\PowerSchool_BaseUrl -ErrorAction SilentlyContinue
                Remove-Item Env:\PowerSchool_ClientID -ErrorAction SilentlyContinue
                Remove-Item Env:\PowerSchool_ClientSecret -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Connection State Management' {
        BeforeEach {
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                return @{
                    access_token = 'test-token-123'
                    expires_in = 3600
                }
            }
        }

        It 'Should not reconnect if already connected and token valid' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force

            # First connection
            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret
            
            # Second connection without Force should not make another API call
            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret
            
            # Should only be invoked once (first connection)
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-RestMethod -Times 1
        }

        It 'Should reconnect when Force parameter is used' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force

            # First connection
            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret
            
            # Second connection with Force should make another API call
            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret -Force
            
            # Should be invoked twice
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-RestMethod -Times 2
        }
    }

    Context 'Security' {
        BeforeEach {
            Mock -ModuleName FSEnrollment-PSSync Invoke-RestMethod {
                return @{
                    access_token = 'test-token-123'
                    expires_in = 3600
                }
            }
        }

        It 'Should store token as SecureString' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force

            Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret
            
            # Verify token is stored as SecureString
            InModuleScope FSEnrollment-PSSync {
                $script:PowerSchoolToken | Should -BeOfType [SecureString]
            }
        }

        It 'Should accept SecureString for ClientSecret' {
            $testSecret = ConvertTo-SecureString -String 'test-secret' -AsPlainText -Force

            { Connect-PowerSchool -BaseUrl 'https://test.powerschool.com' -ClientId 'test-client' -ClientSecret $testSecret } | Should -Not -Throw
        }
    }
}
