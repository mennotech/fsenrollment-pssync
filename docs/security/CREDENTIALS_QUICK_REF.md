# 🔒 Secure Credentials Quick Reference

## Setup (First Time)

```powershell
# 1. Create your .env file
Copy-Item config\.env.example config\.env

# 2. Edit with your credentials (use any text editor)
notepad config\.env

# 3. Enable git hooks to prevent leaks
git config core.hooksPath .githooks
```

## Daily Usage

```powershell
# Load credentials securely
Import-Module ./fsenrollment-pssync/FSEnrollment-PSSync.psd1
$creds = Import-EnvironmentCredentials

# Use in API calls
$secret = ConvertFrom-SecureCredential -SecureString $creds.PowerSchoolClientSecret
# ... use immediately ...
$secret = $null  # Always clear after use!
```

## Before Every Commit

```powershell
# Run security tests
Invoke-Pester -Path .\fsenrollment-pssync\tests\Security.CredentialLeak.Tests.ps1
```

## Production Deployment

```powershell
# Load from environment variables and clear them
$creds = Import-EnvironmentCredentials -EnvFilePath $null -ClearEnvironmentVariables
```

## What's Protected

✅ `.env` files (ignored by git)  
✅ `POWERSCHOOL_CLIENT_SECRET`  
✅ `POWERSCHOOL_CLIENT_ID`  
✅ `SFTP_PASSWORD`  
✅ `DB_CONNECTION_STRING`  
✅ `CACHE_ENCRYPTION_KEY`  

## Common Mistakes to Avoid

❌ Don't commit `.env` files  
❌ Don't hardcode credentials in scripts  
❌ Don't bypass pre-commit hooks  
❌ Don't log credential values  
❌ Don't keep plaintext variables longer than needed  

## Need Help?

📖 [Full Documentation](Secure-Credential-Management.md)  
🔧 [Example Script](../scripts/Example-SecureCredentials.ps1)  
🧪 [Security Tests](../fsenrollment-pssync/tests/Security.CredentialLeak.Tests.ps1)  
🪝 [Git Hooks](../.githooks/README.md)  
