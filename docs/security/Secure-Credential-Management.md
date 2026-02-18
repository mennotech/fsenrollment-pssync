# Secure Credential Management

## Overview

This document describes the secure credential management system for the Final Site Enrollment PowerSchool Sync project. The system is designed to prevent credential leaks while maintaining flexibility for different deployment environments.

## Security Principles

1. **Never commit credentials to git** - Use `.env` files (ignored by git) for local development
2. **Encrypt credentials in memory** - Convert sensitive data to SecureStrings immediately after loading
3. **Clear environment variables** - Remove credentials from environment after loading to minimize exposure window
4. **Minimize plaintext exposure** - Only decrypt when absolutely necessary for API calls
5. **Automated scanning** - Run tests to detect credential leaks before they're committed

## Local Development Setup

### 1. Create Your .env File

Copy the example file and fill in your credentials:

```powershell
Copy-Item config\.env.example config\.env
# Edit config\.env with your actual credentials
```

**Never commit this file to git** - it's already excluded in `.gitignore`.

### 2. Connect to PowerSchool (Simplest Method)

The easiest way to use `.env` credentials is with `Connect-PowerSchool`, which automatically loads them:

```powershell
# Import the module
Import-Module .\fsenrollment-pssync\FSEnrollment-PSSync.psd1

# Connect to PowerSchool - no parameters needed!
# Credentials are loaded automatically from .env file
Connect-PowerSchool

# Now use the API
$students = Invoke-PowerQuery -Endpoint 'ws/v1/student' -Query 'id=1051'
```

**Credential Loading Priority:**
1. Explicit parameters (if you pass them to `Connect-PowerSchool`)
2. `.env` file credentials (loaded automatically)
3. Environment variables (`PowerSchool_BaseUrl`, `PowerSchool_ClientID`, `PowerSchool_ClientSecret`)
4. Interactive prompts (fallback if nothing else is available)

### 3. Manual Credential Loading (Advanced)

For custom scripts that need direct access to credentials:

```powershell
# Import the module
Import-Module .\fsenrollment-pssync\FSEnrollment-PSSync.psd1

# Load credentials from .env file
$credentials = Import-EnvironmentCredentials

# Access non-sensitive configuration (plain text)
$apiUrl = $credentials.PowerSchoolUrl

# Access sensitive credentials (SecureString)
$clientId = ConvertFrom-SecureCredential -SecureString $credentials.PowerSchoolClientId
$clientSecret = ConvertFrom-SecureCredential -SecureString $credentials.PowerSchoolClientSecret

# Use immediately in API call
$authResponse = Invoke-RestMethod -Uri "$apiUrl/oauth/token" `
    -Method Post `
    -Body @{
        client_id = $clientId
        client_secret = $clientSecret
        grant_type = 'client_credentials'
    }

# Clear plaintext variables immediately after use
$clientId = $null
$clientSecret = $null
```

## Production Deployment

### Linux VM Setup

For production deployments on Linux VMs, use environment variables set securely at the system level:

```bash
# Set environment variables securely (e.g., via systemd service file, Azure Key Vault, etc.)
export POWERSCHOOL_URL="https://your-instance.powerschool.com"
export POWERSCHOOL_CLIENT_ID="your_client_id"
export POWERSCHOOL_CLIENT_SECRET="your_client_secret"
```

### Load and Clear Credentials on VM Boot

Create a startup script that loads credentials and immediately clears them from environment:

```powershell
#!/usr/bin/env pwsh

# Import module
Import-Module /opt/fsenrollment-pssync/FSEnrollment-PSSync.psd1

# Load credentials from environment variables and clear them immediately
$credentials = Import-EnvironmentCredentials -EnvFilePath $null -ClearEnvironmentVariables

# Store encrypted credentials for the session
# These are now SecureStrings in memory, environment variables are cleared
$global:AppCredentials = $credentials

# Credentials are now:
# 1. Loaded into memory as SecureStrings
# 2. Environment variables have been cleared
# 3. Garbage collection has been forced to clear any lingering references

Write-Host "Credentials loaded and secured in memory"
```

### Benefits of This Approach

1. **Short exposure window** - Environment variables exist only during initial load
2. **Memory encryption** - Credentials stored as SecureStrings (encrypted in memory)
3. **No disk persistence** - No `.env` file needed in production
4. **Garbage collection** - Forces cleanup of any temporary plaintext references
5. **Audit trail** - Logs when credentials are loaded and cleared

## Automated Security Testing

### Run Security Tests Before Committing

```powershell
# Run only security tests
Invoke-Pester -Path .\fsenrollment-pssync\tests\Security.CredentialLeak.Tests.ps1

# Run all tests including security
Invoke-Pester -Path .\fsenrollment-pssync\tests
```

### What the Security Tests Check

1. **Git-tracked files** - Scans all files tracked by git for credential patterns:
   - API keys and tokens (20+ characters)
   - Passwords in assignments or connection strings
   - Private key headers
   - AWS credentials
   - Authorization headers with tokens
   - High-entropy secret values

2. **PowerShell files** - Checks for sensitive variable assignments with real values:
   - `POWERSCHOOL_CLIENT_SECRET`
   - `POWERSCHOOL_CLIENT_ID`
   - `SFTP_PASSWORD`
   - `CACHE_ENCRYPTION_KEY`
   - Other sensitive variables

3. **Git ignore configuration** - Verifies `.env` files are properly excluded

4. **Example files** - Ensures template files only contain placeholders

5. **Secure coding practices** - Validates use of SecureString and credential clearing

### Add to Pre-commit Hook (Optional)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
echo "Running security credential leak tests..."
pwsh -Command "Invoke-Pester -Path ./fsenrollment-pssync/tests/Security.CredentialLeak.Tests.ps1 -CI"

if [ $? -ne 0 ]; then
    echo "❌ Security tests failed! Commit blocked."
    echo "Please remove any credentials from your changes."
    exit 1
fi

echo "✅ Security tests passed"
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Best Practices

### DO ✅

- Use `.env` files for local development (never commit them)
- Use environment variables in production VMs
- Convert sensitive data to SecureString immediately after loading
- Clear environment variables after loading with `-ClearEnvironmentVariables`
- Clear plaintext variables immediately after use (`$var = $null`)
- Run security tests before committing code
- Use placeholder values in example files (`your_`, `example_`, `<REPLACE>`, etc.)
- Store credentials in Azure Key Vault, AWS Secrets Manager, or similar for cloud deployments

### DON'T ❌

- Don't commit `.env` files to git
- Don't hardcode credentials in scripts
- Don't log or display credential values
- Don't store credentials in plain text configuration files tracked by git
- Don't keep credentials in environment variables longer than necessary
- Don't use real credentials in example or test files
- Don't skip security tests when making changes

## Credential Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Credential Source                                        │
│    ├─ Local Dev: .env file                                  │
│    └─ Production: Environment variables                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Import-EnvironmentCredentials                            │
│    ├─ Loads from environment variables                      │
│    ├─ Converts sensitive data to SecureString               │
│    └─ Optionally clears environment variables               │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. In-Memory Storage (Encrypted)                            │
│    ├─ Stored as SecureStrings                               │
│    ├─ Protected by Windows DPAPI / Linux encryption         │
│    └─ Garbage collected to remove plaintext refs            │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. ConvertFrom-SecureCredential (When Needed)               │
│    ├─ Decrypt only when required for API calls              │
│    ├─ Use BSTR marshaling for secure conversion             │
│    └─ Zero out memory immediately after conversion          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Immediate Use & Clear                                    │
│    ├─ Use in API call immediately                           │
│    ├─ Set variable to $null after use                       │
│    └─ Let garbage collector clean up                        │
└─────────────────────────────────────────────────────────────┘
```

## Compliance & Auditing

### For Compliance Requirements

If your organization has specific compliance requirements (GDPR, HIPAA, PCI-DSS, etc.):

1. **Audit logging** - Log when credentials are accessed (but not their values)
2. **Rotation** - Implement credential rotation policies
3. **Access control** - Limit who can access production environment variables
4. **Encryption at rest** - Use encrypted storage for `.env` files if required
5. **Secret management** - Consider enterprise secret management solutions

### Recommended Secret Management Solutions

- **Azure Key Vault** - For Azure deployments
- **AWS Secrets Manager** - For AWS deployments
- **HashiCorp Vault** - For cross-platform enterprise deployments
- **CyberArk** - For enterprise credential management
- **Linux keyring** - For Linux local development (`secret-tool`, `gnome-keyring`)

## Troubleshooting

### "Cannot load credentials" Error

1. Check that `.env` file exists: `Test-Path config\.env`
2. Verify `.env` file format (KEY=VALUE, one per line)
3. Check for syntax errors in `.env` (no spaces around `=`)
4. Verify environment variables are set: `Get-ChildItem Env:POWERSCHOOL_*`

### Security Test Failures

1. **Credential pattern detected** - Review the file and match reported, replace with placeholder
2. **Real value in variable** - Use example values like `your_client_id_here` in example files
3. **.env file tracked by git** - Remove it: `git rm --cached config/.env`

### SecureString Decryption Errors

- **Cross-platform issue** - SecureString encryption differs between Windows and Linux
- **Solution** - Use the same OS for encryption and decryption, or use cross-platform encryption

## Additional Resources

- [PowerShell SecureString Documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertto-securestring)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_CheatSheet.html)
- [Azure Key Vault with PowerShell](https://learn.microsoft.com/en-us/azure/key-vault/general/manage-with-cli2)
