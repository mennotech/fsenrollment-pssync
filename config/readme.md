# configuration

This directory contains configuration files for the fsenrollmentpssync application.

## Security Warning

**NEVER commit configuration files containing secrets, credentials, or sensitive data to the repository!**

## Configuration Files

Configuration files should use formats like:
- JSON (`.json`)
- YAML (`.yaml` or `.yml`)
- PowerShell Data Files (`.psd1`)
- Environment files (`.env`)

## Guidelines

- Use environment variables for sensitive data
- Provide example configuration files with `.example` suffix
- Document all configuration options
- Validate configuration on load
- Use secure credential storage (Azure Key Vault, secret stores)
- Keep development and production configurations separate

## Example Configuration Structure

```powershell
# config.example.psd1
@{
    PowerSchool = @{
        BaseUrl = 'https://powerschool.example.com/ws/v1'
        ClientId = 'your-client-id'
        # Do not store secrets here - use secure credential storage
        Timeout = 30
        RetryAttempts = 3
    }
    
    FinalSiteEnrollment = @{
        DataPath = '/upload'
        # Do not store credentials here - use secure credential storage
    }
    
    Logging = @{
        LogLevel = 'Info' # Debug, Info, Warning, Error
        LogPath = './logs'
        MaxLogSizeMB = 10
        RetentionDays = 30
    }
    
    Sync = @{
        BatchSize = 100
        EnableApprovalWorkflow = $true
        DryRun = $false
    }
}
```

## Protected Files

The `.gitignore` file is configured to exclude:
- `*credentials*`
- `*secrets*`
- `*.key`
- `*.pfx`
- `*.p12`
- `*.env`

## Best Practices

1. Use example files for documentation (e.g., `config.example.psd1`)
2. Store actual configuration files outside the repository or use secure storage
3. Use environment variables for deployment-specific settings
4. Implement configuration validation in code
5. Document all configuration options thoroughly
