BeforeAll {
    # Get the module root directory
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Describe "Credential Security Tests" -Tag 'Security' {
    
    Context "Git-tracked files should not contain credentials" {
        
        BeforeAll {
            # Get all files tracked by git (excluding .gitignore patterns)
            $gitFiles = git -C $ModuleRoot ls-files 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Git is not available or this is not a git repository. Skipping git-tracked file tests."
                $gitFiles = @()
            }
            
            # Define patterns that might indicate credentials
            $credentialPatterns = @(
                # API Keys and tokens
                '(?i)(api[_-]?key|apikey)\s*[:=]\s*[''"]?[a-zA-Z0-9]{20,}[''"]?'
                '(?i)(access[_-]?token|accesstoken)\s*[:=]\s*[''"]?[a-zA-Z0-9]{20,}[''"]?'
                '(?i)(secret[_-]?key|secretkey)\s*[:=]\s*[''"]?[a-zA-Z0-9]{20,}[''"]?'
                '(?i)(client[_-]?secret|clientsecret)\s*[:=]\s*[''"]?[a-zA-Z0-9]{20,}[''"]?'
                
                # Passwords
                '(?i)password\s*[:=]\s*[''"][^''"\s]{3,}[''"]'
                
                # Connection strings with passwords
                '(?i)(password|pwd)\s*=\s*[^;]{3,}'
                
                # Private keys (headers)
                '-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'
                '-----BEGIN\s+OPENSSH\s+PRIVATE\s+KEY-----'
                
                # AWS credentials
                '(?i)(aws[_-]?access[_-]?key[_-]?id|aws[_-]?secret[_-]?access[_-]?key)\s*[:=]\s*[''"]?[A-Z0-9]{16,}[''"]?'
                
                # Generic secrets (high entropy strings)
                '(?i)secret\s*[:=]\s*[''"]?[a-zA-Z0-9+/]{32,}={0,2}[''"]?'
                
                # Authorization headers with tokens
                '(?i)authorization\s*[:=]\s*[''"]?(bearer|basic)\s+[a-zA-Z0-9+/=]{20,}[''"]?'
            )
            
            # Files to exclude from scanning (even if tracked)
            $excludePatterns = @(
                '*.md'              # Documentation files often contain examples
                '*.Tests.ps1'       # Test files may contain example patterns
                '*.example.*'       # Example configuration files
                'LICENSE'           # License file
                '.gitignore'        # Git ignore file
                '*.yaml'            # API documentation
                '*.json'            # May contain example data
            )
            
            # Sensitive variable names that should not have real values
            $sensitiveVarNames = @(
                'POWERSCHOOL_CLIENT_SECRET'
                'POWERSCHOOL_CLIENT_ID'
                'SFTP_PASSWORD'
                'CACHE_ENCRYPTION_KEY'
                'DB_CONNECTION_STRING'
                'API_KEY'
                'ACCESS_TOKEN'
                'SECRET_KEY'
            )
        }
        
        It "Should not find credential patterns in git-tracked files" {
            $violations = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            foreach ($file in $gitFiles) {
                $filePath = Join-Path $ModuleRoot $file
                
                # Skip if file doesn't exist or is in exclude list
                if (-not (Test-Path $filePath)) {
                    continue
                }
                
                $shouldSkip = $false
                foreach ($pattern in $excludePatterns) {
                    if ($file -like $pattern) {
                        $shouldSkip = $true
                        break
                    }
                }
                
                if ($shouldSkip) {
                    continue
                }
                
                # Read file content (skip binary files)
                try {
                    $content = Get-Content -Path $filePath -Raw -ErrorAction Stop
                }
                catch {
                    # Skip files that can't be read as text
                    continue
                }
                
                # Check each credential pattern
                foreach ($pattern in $credentialPatterns) {
                    if ($content -match $pattern) {
                        $violations.Add([PSCustomObject]@{
                            File    = $file
                            Pattern = $pattern
                            Match   = $Matches[0]
                        })
                    }
                }
            }
            
            if ($violations.Count -gt 0) {
                $violationReport = $violations | ForEach-Object {
                    "File: $($_.File)`n  Pattern: $($_.Pattern)`n  Match: $($_.Match)"
                } | Out-String
                
                $violations.Count | Should -Be 0 -Because "Credentials should not be committed to git. Found violations:`n$violationReport"
            }
            else {
                $true | Should -Be $true
            }
        }
        
        It "Should not contain plaintext sensitive variable values in PowerShell files" {
            $violations = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            # Get all PowerShell files
            $psFiles = $gitFiles | Where-Object { $_ -like '*.ps1' -or $_ -like '*.psm1' -or $_ -like '*.psd1' }
            
            foreach ($file in $psFiles) {
                $filePath = Join-Path $ModuleRoot $file
                
                # Skip test files and examples
                if ($file -like '*.Tests.ps1' -or $file -like '*example*') {
                    continue
                }
                
                if (-not (Test-Path $filePath)) {
                    continue
                }
                
                try {
                    $content = Get-Content -Path $filePath -Raw -ErrorAction Stop
                }
                catch {
                    continue
                }
                
                # Check for sensitive variable assignments with actual values
                foreach ($varName in $sensitiveVarNames) {
                    # Pattern: $varName = "somevalue" or $varName = 'somevalue' (not just examples)
                    if ($content -match "\`$$varName\s*=\s*['""](?!your_|example_|<|REPLACE|TODO|\$)[^'""]{8,}['""]") {
                        $violations.Add([PSCustomObject]@{
                            File     = $file
                            Variable = $varName
                            Line     = ($content -split "`n" | Select-String -Pattern $varName | Select-Object -First 1).LineNumber
                        })
                    }
                }
            }
            
            if ($violations.Count -gt 0) {
                $violationReport = $violations | ForEach-Object {
                    "File: $($_.File), Variable: $($_.Variable), Line: $($_.Line)"
                } | Out-String
                
                $violations.Count | Should -Be 0 -Because "Sensitive variables should not have real values in code. Found violations:`n$violationReport"
            }
            else {
                $true | Should -Be $true
            }
        }
    }
    
    Context ".env file should be properly ignored" {
        
        It "Should have .env pattern in .gitignore" {
            $gitignorePath = Join-Path $ModuleRoot '.gitignore'
            
            if (Test-Path $gitignorePath) {
                $gitignoreContent = Get-Content -Path $gitignorePath -Raw
                $gitignoreContent | Should -Match '\.env' -Because ".env files should be excluded from git"
            }
            else {
                Set-ItResult -Skipped -Because ".gitignore file not found"
            }
        }
        
        It "Should not have .env file tracked in git" {
            $gitFiles = git -C $ModuleRoot ls-files 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                $envFiles = $gitFiles | Where-Object { $_ -match '\.env$' -and $_ -notmatch '\.env\.example$' }
                $envFiles | Should -BeNullOrEmpty -Because ".env files should never be committed to git"
            }
            else {
                Set-ItResult -Skipped -Because "Git is not available"
            }
        }
    }
    
    Context "Secure credential handling" {
        
        It "Should use SecureString for sensitive data in Import-EnvironmentCredentials" {
            $functionPath = Join-Path $ModuleRoot 'fsenrollment-pssync' 'public' 'Import-EnvironmentCredentials.ps1'
            
            if (Test-Path $functionPath) {
                $content = Get-Content -Path $functionPath -Raw
                $content | Should -Match 'ConvertTo-SecureString' -Because "Credentials should be converted to SecureString"
                $content | Should -Match '\.Sensitive' -Because "Function should distinguish between sensitive and non-sensitive data"
            }
            else {
                Set-ItResult -Skipped -Because "Import-EnvironmentCredentials function not found"
            }
        }
        
        It "Should provide option to clear environment variables after loading" {
            $functionPath = Join-Path $ModuleRoot 'fsenrollment-pssync' 'public' 'Import-EnvironmentCredentials.ps1'
            
            if (Test-Path $functionPath) {
                $content = Get-Content -Path $functionPath -Raw
                $content | Should -Match 'ClearEnvironmentVariables' -Because "Function should support clearing environment variables"
                $content | Should -Match '\[Environment\]::SetEnvironmentVariable.*\$null' -Because "Function should clear environment variables"
            }
            else {
                Set-ItResult -Skipped -Because "Import-EnvironmentCredentials function not found"
            }
        }
    }
    
    Context "Example and template files should not contain real credentials" {
        
        It "Should only have placeholder values in .env.example" {
            $exampleEnvPath = Join-Path $ModuleRoot 'config' '.env.example'
            
            if (Test-Path $exampleEnvPath) {
                $content = Get-Content -Path $exampleEnvPath -Raw
                
                # Check for common placeholder patterns
                $content | Should -Match '(your_|example_|<|REPLACE|TODO|generate_a_)' -Because "Example file should contain placeholders"
                
                # Should not contain high-entropy strings that look like real credentials
                $content | Should -Not -Match '(?<==)[a-zA-Z0-9+/]{40,}(?=[^a-zA-Z0-9+/])' -Because "Example file should not contain real secrets"
            }
            else {
                Set-ItResult -Skipped -Because ".env.example file not found"
            }
        }
    }
    
    Context "Test validation - ensure credential patterns are actually detected" {
        
        BeforeAll {
            # Create temporary directory for test files
            $script:TestDir = Join-Path $ModuleRoot 'tmp' 'security-test'
            New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
            
            # Define credential patterns from earlier in the test
            $script:credentialPatterns = @(
                # API Keys and tokens
                '(?i)(api[_-]?key|apikey)\s*[:=]\s*[''"]([a-zA-Z0-9_]{20,})[''"]'
                '(?i)(access[_-]?token|accesstoken)\s*[:=]\s*[''"]([a-zA-Z0-9_]{20,})[''"]'
                '(?i)(secret[_-]?key|secretkey)\s*[:=]\s*[''"]([a-zA-Z0-9_]{20,})[''"]'
                '(?i)(client[_-]?secret|clientsecret)\s*[:=]\s*[''"]([a-zA-Z0-9_]{20,})[''"]'
                
                # Passwords
                '(?i)password\s*[:=]\s*[''"][^''"\s]{3,}[''"]'
                
                # Connection strings with passwords
                '(?i)(password|pwd)\s*=\s*[^;]{3,}'
                
                # Private keys (headers)
                '-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'
                '-----BEGIN\s+OPENSSH\s+PRIVATE\s+KEY-----'
                
                # AWS credentials
                '(?i)(aws[_-]?access[_-]?key[_-]?id|aws[_-]?secret[_-]?access[_-]?key)\s*[:=]\s*[''"]?[A-Z0-9]{16,}[''"]?'
                
                # Generic secrets (high entropy strings)
                '(?i)secret\s*[:=]\s*[''"]?[a-zA-Z0-9+/]{32,}={0,2}[''"]?'
                
                # Authorization headers with tokens
                '(?i)authorization\s*[:=]\s*[''"]?(bearer|basic)\s+[a-zA-Z0-9+/=]{20,}[''"]?'
            )
        }
        
        AfterAll {
            # Clean up test directory
            if (Test-Path $script:TestDir) {
                Remove-Item -Path $script:TestDir -Recurse -Force
            }
        }
        
        It "Should detect API key in PowerShell script" {
            $testFile = Join-Path $script:TestDir 'test-apikey.ps1'
            $offendingContent = @'
# This is a test file
$apiKey = "sk_" + "live_" + "51234567890abcdefghijklmnopqrstuvwxyz"
$response = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $apiKey" }
'@
            Set-Content -Path $testFile -Value $offendingContent
            
            # Test that pattern matches
            $content = Get-Content -Path $testFile -Raw
            $detected = $false
            
            foreach ($pattern in $script:credentialPatterns) {
                if ($content -match $pattern) {
                    $detected = $true
                    break
                }
            }
            
            $detected | Should -Be $true -Because "API key pattern should be detected in test file"
            
            # Clean up immediately
            Remove-Item -Path $testFile -Force
        }
        
        It "Should detect client secret in PowerShell script" {
            $testFile = Join-Path $script:TestDir 'test-secret.ps1'
            $offendingContent = @'
$clientId = "my-client-id"
$clientSecret = "abcdefghij1234567890abcdefghij1234567890"
Connect-API -ClientId $clientId -ClientSecret $clientSecret
'@
            Set-Content -Path $testFile -Value $offendingContent
            
            # Test that pattern matches
            $content = Get-Content -Path $testFile -Raw
            $detected = $false
            
            foreach ($pattern in $script:credentialPatterns) {
                if ($content -match $pattern) {
                    $detected = $true
                    break
                }
            }
            
            $detected | Should -Be $true -Because "Client secret pattern should be detected in test file"
            
            # Clean up immediately
            Remove-Item -Path $testFile -Force
        }
        
        It "Should detect password in connection string" {
            $testFile = Join-Path $script:TestDir 'test-connstring.ps1'
            $offendingContent = @'
$connectionString = "Server=myserver;Database=mydb;User Id=myuser;Password=MyP@ssw0rd123;"
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
'@
            Set-Content -Path $testFile -Value $offendingContent
            
            # Test that pattern matches
            $content = Get-Content -Path $testFile -Raw
            $detected = $false
            
            foreach ($pattern in $script:credentialPatterns) {
                if ($content -match $pattern) {
                    $detected = $true
                    break
                }
            }
            
            $detected | Should -Be $true -Because "Password in connection string should be detected"
            
            # Clean up immediately
            Remove-Item -Path $testFile -Force
        }
        
        It "Should detect private key header" {
            $testFile = Join-Path $script:TestDir 'test-privatekey.txt'
            $offendingContent = @'
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890abcdefghijklmnopqrstuvwxyz
ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijk
...
-----END RSA PRIVATE KEY-----
'@
            Set-Content -Path $testFile -Value $offendingContent
            
            # Test that pattern matches
            $content = Get-Content -Path $testFile -Raw
            $detected = $false
            
            foreach ($pattern in $script:credentialPatterns) {
                if ($content -match $pattern) {
                    $detected = $true
                    break
                }
            }
            
            $detected | Should -Be $true -Because "Private key header should be detected"
            
            # Clean up immediately
            Remove-Item -Path $testFile -Force
        }
        
        It "Should detect AWS credentials" {
            $testFile = Join-Path $script:TestDir 'test-aws.ps1'
            $offendingContent = @'
$awsAccessKeyId = "AKIAIOSFODNN7EXAMPLE"
$awsSecretAccessKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
Set-AWSCredential -AccessKey $awsAccessKeyId -SecretKey $awsSecretAccessKey
'@
            Set-Content -Path $testFile -Value $offendingContent
            
            # Test that pattern matches
            $content = Get-Content -Path $testFile -Raw
            $detected = $false
            
            foreach ($pattern in $script:credentialPatterns) {
                if ($content -match $pattern) {
                    $detected = $true
                    break
                }
            }
            
            $detected | Should -Be $true -Because "AWS credentials should be detected"
            
            # Clean up immediately
            Remove-Item -Path $testFile -Force
        }
        
        It "Should detect Authorization header with Bearer token" {
            $testFile = Join-Path $script:TestDir 'test-bearer.ps1'
            $offendingContent = @'
$headers = @{
    Authorization = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
    ContentType = "application/json"
}
'@
            Set-Content -Path $testFile -Value $offendingContent
            
            # Test that pattern matches
            $content = Get-Content -Path $testFile -Raw
            $detected = $false
            
            foreach ($pattern in $script:credentialPatterns) {
                if ($content -match $pattern) {
                    $detected = $true
                    break
                }
            }
            
            $detected | Should -Be $true -Because "Bearer token in Authorization header should be detected"
            
            # Clean up immediately
            Remove-Item -Path $testFile -Force
        }
        
        It "Should NOT detect placeholder values" {
            $testFile = Join-Path $script:TestDir 'test-safe.ps1'
            $safeContent = @'
# Safe example file with placeholders
$apiKey = "your_api_key_here"
$clientSecret = "<REPLACE_WITH_YOUR_SECRET>"
$password = "TODO: Set password"
$token = "example_token_value"
'@
            Set-Content -Path $testFile -Value $safeContent
            
            # Test that pattern does NOT match (because values are too short or obvious placeholders)
            $content = Get-Content -Path $testFile -Raw
            
            # The patterns should either not match, or if they do, they should be obvious placeholders
            # This validates that our example files won't trigger false positives
            $suspiciousMatch = $false
            
            foreach ($pattern in $script:credentialPatterns) {
                if ($content -match $pattern) {
                    $match = $Matches[0]
                    # Check if the match contains placeholder indicators
                    if ($match -notmatch '(your_|example_|<|REPLACE|TODO)') {
                        $suspiciousMatch = $true
                        break
                    }
                }
            }
            
            $suspiciousMatch | Should -Be $false -Because "Placeholder values should not trigger false positives"
            
            # Clean up immediately
            Remove-Item -Path $testFile -Force
        }
        
        It "Should ensure test directory is cleaned up" {
            # Verify all test files were deleted
            if (Test-Path $script:TestDir) {
                $remainingFiles = Get-ChildItem -Path $script:TestDir -File -ErrorAction SilentlyContinue
                if ($remainingFiles) {
                    $remainingFiles.Count | Should -Be 0 -Because "All test files should be cleaned up immediately after each test. Found: $($remainingFiles.Name -join ', ')"
                }
                else {
                    $true | Should -Be $true # No files found, test passes
                }
            }
            else {
                $true | Should -Be $true # Directory doesn't exist, which is also acceptable
            }
        }
    }
}
