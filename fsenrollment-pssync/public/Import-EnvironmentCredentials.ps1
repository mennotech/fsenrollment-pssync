function Import-EnvironmentCredentials {
    <#
    .SYNOPSIS
        Securely imports credentials from environment variables or .env file into memory.
    
    .DESCRIPTION
        This function loads credentials from environment variables or a .env file,
        converts them to SecureStrings in memory, and optionally clears the original
        environment variables to minimize exposure. This helps prevent credential leaks
        and keeps sensitive data encrypted in memory.
    
    .PARAMETER EnvFilePath
        Path to the .env file. Defaults to config/.env in the module root.
    
    .PARAMETER ClearEnvironmentVariables
        If specified, clears environment variables after loading them into secure storage.
        Recommended for production environments to minimize credential exposure.
    
    .PARAMETER Prefix
        Prefix for environment variable names. Defaults to empty string.
        Useful if you want to namespace variables (e.g., "FSPSSYNC_").
    
    .EXAMPLE
        $credentials = Import-EnvironmentCredentials -ClearEnvironmentVariables
        
        # Access credentials as SecureStrings:
        $apiUrl = $credentials.PowerSchoolUrl
        $clientId = $credentials.PowerSchoolClientId
        $clientSecret = $credentials.PowerSchoolClientSecret
    
    .EXAMPLE
        # In production, load from environment variables only (no .env file)
        $credentials = Import-EnvironmentCredentials -EnvFilePath $null -ClearEnvironmentVariables
    
    .OUTPUTS
        PSCustomObject with credential properties as SecureStrings or plain strings
    
    .NOTES
        - The .env file is only loaded if it exists and EnvFilePath is provided
        - Environment variables take precedence over .env file values
        - Sensitive values are stored as SecureStrings in the returned object
        - Use ConvertFrom-SecureString to decrypt when needed for API calls
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$EnvFilePath,
        
        [Parameter()]
        [switch]$ClearEnvironmentVariables,
        
        [Parameter()]
        [string]$Prefix = ""
    )
    
    begin {
        Write-Verbose "Starting credential import process"
        
        # Determine default path if not specified
        if (-not $PSBoundParameters.ContainsKey('EnvFilePath')) {
            $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $EnvFilePath = Join-Path $moduleRoot "config" ".env"
            Write-Verbose "Using default env file path: $EnvFilePath"
        }
    }
    
    process {
        # Load .env file if it exists
        if ($EnvFilePath -and (Test-Path -Path $EnvFilePath -PathType Leaf)) {
            Write-Verbose "Loading environment file: $EnvFilePath"
            
            try {
                $envContent = Get-Content -Path $EnvFilePath -ErrorAction Stop
                
                foreach ($line in $envContent) {
                    # Skip comments and empty lines
                    if ($line -match '^\s*#' -or $line -match '^\s*$') {
                        continue
                    }
                    
                    # Parse KEY=VALUE format
                    if ($line -match '^([^=]+)=(.*)$') {
                        $key = $Matches[1].Trim()
                        $value = $Matches[2].Trim()
                        
                        # Remove quotes if present
                        $value = $value -replace '^["'']|["'']$', ''
                        
                        # Only set if not already in environment
                        if (-not [Environment]::GetEnvironmentVariable($key)) {
                            [Environment]::SetEnvironmentVariable($key, $value, [EnvironmentVariableTarget]::Process)
                            Write-Debug "Loaded variable from .env: $key"
                        }
                    }
                }
            }
            catch {
                Write-Error "Failed to load environment file: $_"
                throw
            }
        }
        elseif ($EnvFilePath) {
            Write-Warning "Environment file not found: $EnvFilePath"
        }
        
        # Define credential mappings (variable name -> property name, isSensitive)
        $credentialMap = @{
            "${Prefix}POWERSCHOOL_URL"              = @{ Property = 'PowerSchoolUrl'; Sensitive = $false }
            "${Prefix}POWERSCHOOL_CLIENT_ID"        = @{ Property = 'PowerSchoolClientId'; Sensitive = $true }
            "${Prefix}POWERSCHOOL_CLIENT_SECRET"    = @{ Property = 'PowerSchoolClientSecret'; Sensitive = $true }
            "${Prefix}SFTP_HOST"                    = @{ Property = 'SftpHost'; Sensitive = $false }
            "${Prefix}SFTP_PORT"                    = @{ Property = 'SftpPort'; Sensitive = $false }
            "${Prefix}SFTP_USERNAME"                = @{ Property = 'SftpUsername'; Sensitive = $true }
            "${Prefix}SFTP_PASSWORD"                = @{ Property = 'SftpPassword'; Sensitive = $true }
            "${Prefix}SFTP_PRIVATE_KEY_PATH"        = @{ Property = 'SftpPrivateKeyPath'; Sensitive = $false }
            "${Prefix}DB_CONNECTION_STRING"         = @{ Property = 'DbConnectionString'; Sensitive = $true }
            "${Prefix}CACHE_ENCRYPTION_KEY"         = @{ Property = 'CacheEncryptionKey'; Sensitive = $true }
            "${Prefix}LOG_LEVEL"                    = @{ Property = 'LogLevel'; Sensitive = $false }
        }
        
        # Build credential object
        $credentialObject = [PSCustomObject]@{}
        $varsToClears = [System.Collections.Generic.List[string]]::new()
        
        foreach ($envVar in $credentialMap.Keys) {
            $mapping = $credentialMap[$envVar]
            $value = [Environment]::GetEnvironmentVariable($envVar)
            
            if ($null -ne $value -and $value -ne '') {
                if ($mapping.Sensitive) {
                    # Convert to SecureString for sensitive data
                    $secureValue = ConvertTo-SecureString -String $value -AsPlainText -Force
                    $credentialObject | Add-Member -NotePropertyName $mapping.Property -NotePropertyValue $secureValue
                    Write-Verbose "Loaded sensitive credential: $($mapping.Property)"
                }
                else {
                    # Store as plain text for non-sensitive data
                    $credentialObject | Add-Member -NotePropertyName $mapping.Property -NotePropertyValue $value
                    Write-Verbose "Loaded configuration: $($mapping.Property)"
                }
                
                # Track for clearing if requested
                if ($ClearEnvironmentVariables) {
                    $varsToClears.Add($envVar)
                }
            }
            else {
                Write-Debug "Environment variable not set: $envVar"
            }
        }
        
        # Clear environment variables if requested
        if ($ClearEnvironmentVariables -and $varsToClears.Count -gt 0) {
            Write-Verbose "Clearing $($varsToClears.Count) environment variables from memory"
            
            foreach ($varName in $varsToClears) {
                [Environment]::SetEnvironmentVariable($varName, $null, [EnvironmentVariableTarget]::Process)
                Write-Debug "Cleared environment variable: $varName"
            }
            
            # Force garbage collection to clear any lingering references
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            Write-Verbose "Environment variables cleared and garbage collected"
        }
        
        return $credentialObject
    }
}
