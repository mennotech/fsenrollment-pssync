# Git Hooks

This directory contains Git hooks to help maintain code quality and security.

## Available Hooks

### pre-commit

Runs security tests before allowing commits to prevent credential leaks.

**What it checks:**
- Scans git-tracked files for credential patterns
- Validates .env files are properly ignored
- Ensures example files only contain placeholders
- Verifies secure coding practices are followed

## Installation

### Option 1: Configure Git to Use This Directory

This is the recommended approach as it automatically uses the hooks for all developers:

```powershell
# Run from repository root
git config core.hooksPath .githooks
```

### Option 2: Copy Individual Hooks

Copy hooks to `.git/hooks/` directory:

**Windows (PowerShell):**
```powershell
Copy-Item .githooks\pre-commit .git\hooks\pre-commit -Force
```

**Linux/Mac:**
```bash
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Testing Hooks Manually

You can test the pre-commit hook without making a commit:

```powershell
# Run from repository root
.\.githooks\pre-commit

# Or run the tests directly
Invoke-Pester -Path .\fsenrollment-pssync\tests\Security.CredentialLeak.Tests.ps1
```

## Bypassing Hooks (Emergency Only)

If you absolutely need to bypass the hooks (not recommended):

```bash
git commit --no-verify -m "Your commit message"
```

**⚠️ Warning:** Only bypass hooks if you're certain no credentials are being committed!

## Customization

You can modify the hooks in this directory to add additional checks:
- Code formatting validation
- Linting with PSScriptAnalyzer
- Unit test execution
- Documentation checks

## Requirements

- PowerShell 7.0 or higher
- Pester 5.x for running tests

## Troubleshooting

### Hook doesn't run on commit

1. Verify git is configured to use the hooks directory:
   ```powershell
   git config core.hooksPath
   ```

2. Ensure the hook file has execute permissions (Linux/Mac):
   ```bash
   chmod +x .githooks/pre-commit
   ```

3. Check that PowerShell is available in your PATH:
   ```bash
   pwsh --version
   ```

### Hook runs but fails unexpectedly

1. Test the hook manually to see detailed output:
   ```powershell
   .\.githooks\pre-commit
   ```

2. Run the security tests directly:
   ```powershell
   Invoke-Pester -Path .\fsenrollment-pssync\tests\Security.CredentialLeak.Tests.ps1 -Output Detailed
   ```

## Best Practices

1. **Always enable hooks** - They're your first line of defense against credential leaks
2. **Test hooks locally** - Before pushing changes, ensure hooks pass
3. **Don't bypass unless necessary** - The hooks exist for your protection
4. **Update hooks** - When new security checks are added, pull the latest hooks
5. **Share with team** - Ensure all team members have hooks configured
