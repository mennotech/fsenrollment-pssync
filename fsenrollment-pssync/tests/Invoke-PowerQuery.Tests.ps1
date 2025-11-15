#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Invoke-PowerQuery' {
    BeforeEach {
        # Clear any existing connection for clean test state using InModuleScope
        InModuleScope FSEnrollment-PSSync {
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
    }

    Context 'Parameter Validation' {
        It 'Should accept PowerQueryName parameter as string' {
            # Mock the script variables to simulate connection
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            # Mock the functions to avoid actual API calls
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @()
                }
            }
            
            { Invoke-PowerQuery -PowerQueryName 'com.test.query' } | Should -Not -Throw
        }

        It 'Should accept Arguments parameter as hashtable' {
            # Mock the script variables to simulate connection
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            # Mock the functions to avoid actual API calls
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @()
                }
            }
            
            $arguments = @{ id = 123; name = 'test' }
            { Invoke-PowerQuery -PowerQueryName 'com.test.query' -Arguments $arguments } | Should -Not -Throw
        }

        It 'Should accept Arguments parameter as PSCustomObject' {
            # Mock the script variables to simulate connection
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            # Mock the functions to avoid actual API calls
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @()
                }
            }
            
            $arguments = [PSCustomObject]@{ id = 123; name = 'test' }
            { Invoke-PowerQuery -PowerQueryName 'com.test.query' -Arguments $arguments } | Should -Not -Throw
        }
    }

    Context 'Connection Requirements' {
        It 'Should throw when PowerSchool connection is not established' {
            { Invoke-PowerQuery -PowerQueryName 'com.test.query' } | 
                Should -Throw -ExpectedMessage "*PowerSchool connection not established*"
        }

        It 'Should throw when PowerSchool connection is not established with ListAvailable' {
            { Invoke-PowerQuery -ListAvailable } | 
                Should -Throw -ExpectedMessage "*PowerSchool connection not established*"
        }
    }

    Context 'List Available PowerQueries' {
        It 'Should return array of PowerQuery names when ListAvailable is used' {
            # Mock the script variables to simulate connection
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            # Mock the functions
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { 
                return @(
                    'com.scs.dats.students.contacts.email',
                    'com.scs.dats.students.bygrade',
                    'com.custom.powerquery'
                )
            }
            
            $result = Invoke-PowerQuery -ListAvailable
            
            $result | Should -HaveCount 3
            $result | Should -Contain 'com.scs.dats.students.contacts.email'
            $result | Should -Contain 'com.scs.dats.students.bygrade'
            $result | Should -Contain 'com.custom.powerquery'
        }

        It 'Should call Get-AvailablePowerQueries when ListAvailable is used' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @() }
            
            Invoke-PowerQuery -ListAvailable
            
            Should -Invoke -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries -Exactly 1
        }
    }

    Context 'PowerQuery Existence Validation' {
        It 'Should validate PowerQuery exists by default' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.valid.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $false }
            
            { Invoke-PowerQuery -PowerQueryName 'com.invalid.query' } | 
                Should -Throw -ExpectedMessage "*was not found in the available PowerQueries list*"
        }

        It 'Should skip validation when SkipExistenceCheck is used' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @() }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @()
                }
            }
            
            { Invoke-PowerQuery -PowerQueryName 'com.custom.query' -SkipExistenceCheck } | 
                Should -Not -Throw
            
            Should -Not -Invoke -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries
        }

        It 'Should proceed when PowerQuery exists' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.valid.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @()
                }
            }
            
            { Invoke-PowerQuery -PowerQueryName 'com.valid.query' } | Should -Not -Throw
        }
    }

    Context 'PowerQuery Execution' {
        It 'Should execute PowerQuery without arguments' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @(
                        [PSCustomObject]@{ id = 1; name = 'John' },
                        [PSCustomObject]@{ id = 2; name = 'Jane' }
                    )
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.query'
            
            $result | Should -Not -BeNullOrEmpty
            $result.QueryName | Should -Be 'com.test.query'
            $result.RecordCount | Should -Be 2
            $result.Records | Should -HaveCount 2
            
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution -Exactly 1 -ParameterFilter {
                $PowerQueryName -eq 'com.test.query' -and $ArgumentsObject -eq $null
            }
        }

        It 'Should execute PowerQuery with arguments' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @([PSCustomObject]@{ id = 123; grade = 12 })
                }
            }
            
            $arguments = @{ gradeLevel = 12 }
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.query' -Arguments $arguments
            
            $result.QueryName | Should -Be 'com.test.query'
            $result.RecordCount | Should -Be 1
            
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution -Exactly 1 -ParameterFilter {
                $PowerQueryName -eq 'com.test.query' -and $ArgumentsObject -ne $null
            }
        }

        It 'Should handle response with count property' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    count = 5
                    record = @(1, 2, 3, 4, 5)
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.query'
            
            $result.RecordCount | Should -Be 5
            $result.Records | Should -HaveCount 5
        }

        It 'Should include raw response when ShowRawResponse is used' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            $mockRawResponse = [PSCustomObject]@{
                record = @([PSCustomObject]@{ id = 1 })
            }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { return $mockRawResponse }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.query' -ShowRawResponse
            
            $result.PSObject.Properties.Name | Should -Contain 'RawResponse'
            $result.RawResponse | Should -Be $mockRawResponse
        }

        It 'Should not include raw response by default' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @()
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.query'
            
            $result.PSObject.Properties.Name | Should -Not -Contain 'RawResponse'
        }
    }

    Context 'Error Handling' {
        It 'Should throw when Get-AvailablePowerQueries fails' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { throw 'API Error' }
            
            { Invoke-PowerQuery -PowerQueryName 'com.test.query' } | 
                Should -Throw -ExpectedMessage "*API Error*"
        }

        It 'Should throw when Invoke-PowerQueryExecution fails' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { throw 'Execution failed' }
            
            { Invoke-PowerQuery -PowerQueryName 'com.test.query' } | 
                Should -Throw -ExpectedMessage "*Execution failed*"
        }
    }

    Context 'Pipeline Support' {
        It 'Should return structured object suitable for pipeline' {
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.query') }
            Mock -ModuleName FSEnrollment-PSSync Test-PowerQueryExists { return $true }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @([PSCustomObject]@{ id = 1; name = 'Test' })
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.query'
            
            $result | Should -BeOfType [PSCustomObject]
            $result.QueryName | Should -Be 'com.test.query'
            $result.RecordCount | Should -Be 1
            $result.Records | Should -Not -BeNullOrEmpty
            
            # Test pipeline compatibility
            $pipelineResult = $result | Select-Object QueryName, RecordCount
            $pipelineResult.QueryName | Should -Be 'com.test.query'
            $pipelineResult.RecordCount | Should -Be 1
        }
    }
    
    Context 'Pagination Functionality' {
        BeforeEach {
            # Mock PowerSchool connection
            InModuleScope FSEnrollment-PSSync {
                Set-Variable -Name PowerSchoolBaseUrl -Value 'https://test.powerschool.com' -Scope Script
            }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerSchoolAccessToken { return 'mock-token' }
            Mock -ModuleName FSEnrollment-PSSync Get-AvailablePowerQueries { return @('com.test.large.query') }
        }
        
        It 'Should accept AllRecords parameter' {
            Mock -ModuleName FSEnrollment-PSSync Get-PowerQueryRecordCount { return 250 }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                param($PowerQueryName, $ArgumentsObject, $PageNumber, $PageSize)
                
                # Simulate different page responses
                $recordsPerPage = 100
                $startRecord = ($PageNumber - 1) * $recordsPerPage
                $endRecord = [Math]::Min($startRecord + $recordsPerPage - 1, 249)
                $pageRecords = @()
                
                for ($i = $startRecord; $i -le $endRecord; $i++) {
                    $pageRecords += [PSCustomObject]@{ id = $i; name = "Record $i" }
                }
                
                return [PSCustomObject]@{
                    record = $pageRecords
                }
            }
            
            { Invoke-PowerQuery -PowerQueryName 'com.test.large.query' -AllRecords } | Should -Not -Throw
        }
        
        It 'Should retrieve all records using pagination' {
            # Mock 250 total records across 3 pages
            Mock -ModuleName FSEnrollment-PSSync Get-PowerQueryRecordCount { return 250 }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                param($PowerQueryName, $ArgumentsObject, $PageNumber, $PageSize)
                
                # Simulate page-specific responses
                $recordsPerPage = 100
                $startRecord = ($PageNumber - 1) * $recordsPerPage
                
                if ($PageNumber -eq 1) {
                    # Page 1: records 0-99
                    $pageRecords = @()
                    for ($i = 0; $i -le 99; $i++) {
                        $pageRecords += [PSCustomObject]@{ id = $i; name = "Record $i" }
                    }
                }
                elseif ($PageNumber -eq 2) {
                    # Page 2: records 100-199
                    $pageRecords = @()
                    for ($i = 100; $i -le 199; $i++) {
                        $pageRecords += [PSCustomObject]@{ id = $i; name = "Record $i" }
                    }
                }
                elseif ($PageNumber -eq 3) {
                    # Page 3: records 200-249 (only 50 records)
                    $pageRecords = @()
                    for ($i = 200; $i -le 249; $i++) {
                        $pageRecords += [PSCustomObject]@{ id = $i; name = "Record $i" }
                    }
                }
                else {
                    $pageRecords = @()
                }
                
                return [PSCustomObject]@{
                    record = $pageRecords
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.large.query' -AllRecords
            
            $result.QueryName | Should -Be 'com.test.large.query'
            $result.RecordCount | Should -Be 250
            $result.TotalRecords | Should -Be 250
            $result.PaginationUsed | Should -Be $true
            $result.Records.Count | Should -Be 250
            
            # Verify all pages were called
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution -Exactly 3 -ParameterFilter {
                $PageNumber -in @(1, 2, 3) -and $PageSize -eq 100
            }
        }
        
        It 'Should handle empty result sets with AllRecords' {
            Mock -ModuleName FSEnrollment-PSSync Get-PowerQueryRecordCount { return 0 }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                # This should never be called for empty results
                return [PSCustomObject]@{ record = @() }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.large.query' -AllRecords
            
            $result.QueryName | Should -Be 'com.test.large.query'
            $result.RecordCount | Should -Be 0
            $result.TotalRecords | Should -Be 0
            $result.PaginationUsed | Should -Be $true
            $result.Records | Should -Be @()
            
            # Should not call pagination execution for empty results
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution -Exactly 0
        }
        
        It 'Should handle single page results with AllRecords' {
            # Mock 50 total records (less than page size)
            Mock -ModuleName FSEnrollment-PSSync Get-PowerQueryRecordCount { return 50 }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                $pageRecords = @()
                for ($i = 0; $i -le 49; $i++) {
                    $pageRecords += [PSCustomObject]@{ id = $i; name = "Record $i" }
                }
                
                return [PSCustomObject]@{
                    record = $pageRecords
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.large.query' -AllRecords
            
            $result.QueryName | Should -Be 'com.test.large.query'
            $result.RecordCount | Should -Be 50
            $result.TotalRecords | Should -Be 50
            $result.PaginationUsed | Should -Be $true
            $result.Records.Count | Should -Be 50
            
            # Should call exactly one page
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution -Exactly 1 -ParameterFilter {
                $PageNumber -eq 1 -and $PageSize -eq 100
            }
        }
        
        It 'Should pass Arguments to both count and execution calls' {
            $testArgs = @{ grade = '12'; active = $true }
            
            Mock -ModuleName FSEnrollment-PSSync Get-PowerQueryRecordCount { return 150 }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @([PSCustomObject]@{ id = 1; name = "Test Record" })
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.large.query' -Arguments $testArgs -AllRecords
            
            # Verify Arguments were passed to count call
            Should -Invoke -ModuleName FSEnrollment-PSSync Get-PowerQueryRecordCount -ParameterFilter {
                $PowerQueryName -eq 'com.test.large.query' -and
                $ArgumentsObject.grade -eq '12' -and
                $ArgumentsObject.active -eq $true
            }
            
            # Verify Arguments were passed to execution calls
            Should -Invoke -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution -ParameterFilter {
                $PowerQueryName -eq 'com.test.large.query' -and
                $ArgumentsObject.grade -eq '12' -and
                $ArgumentsObject.active -eq $true
            }
        }
        
        It 'Should not include RawResponse with AllRecords parameter' {
            Mock -ModuleName FSEnrollment-PSSync Get-PowerQueryRecordCount { return 100 }
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @([PSCustomObject]@{ id = 1; name = "Test Record" })
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.large.query' -AllRecords -ShowRawResponse
            
            # RawResponse should not be included when using pagination
            $result.PSObject.Properties.Name | Should -Not -Contain 'RawResponse'
        }
        
        It 'Should maintain PaginationUsed property for single-page execution' {
            Mock -ModuleName FSEnrollment-PSSync Invoke-PowerQueryExecution { 
                return [PSCustomObject]@{
                    record = @([PSCustomObject]@{ id = 1; name = "Test Record" })
                }
            }
            
            $result = Invoke-PowerQuery -PowerQueryName 'com.test.large.query'
            
            $result.PaginationUsed | Should -Be $false
            $result.PSObject.Properties.Name | Should -Not -Contain 'TotalRecords'
        }
    }
}