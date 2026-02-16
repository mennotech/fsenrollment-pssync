# Final Site Enrollment → PowerSchool Sync

PowerShell 7+ module to process Final Site Enrollment CSVs and synchronize changes with PowerSchool SIS via API.

## Features

✅ **CSV Parsing**: Import and normalize Final Site Enrollment data  
✅ **Contact Exclusion**: Optionally exclude specific contacts from import via CSV column  
✅ **PowerSchool Authentication**: Secure OAuth 2.0 connection with automatic token renewal  
✅ **Change Detection**: Compare CSV data with PowerSchool to identify new, updated, and unchanged records
✅ **Contact Change Detection**: Comprehensive comparison of contacts, emails, phones, addresses, and relationships  
✅ **PowerQuery Support**: Query PowerSchool data using custom PowerQueries  
✅ **API Integration**: Retrieve student data from PowerSchool with retry logic and rate limiting  
✅ **Cross-Platform**: Works on both Linux and Windows with PowerShell 7+

## Quick Start

### Installation

```powershell
# Import the module
Import-Module ./fsenrollment-pssync/FSEnrollment-PSSync.psd1
```

### Basic Usage

```powershell
# 1. Connect to PowerSchool
$env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
$env:PowerSchool_ClientID = 'your-client-id'
$env:PowerSchool_ClientSecret = 'your-client-secret'

Connect-PowerSchool

# 2. Import CSV data
$csvData = Import-FSCsv -Path './data/students.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_students'

# 3. Get PowerSchool data
$psStudents = Get-PowerSchoolStudent -All

# 4. Detect changes
$changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents

# 5. Review results
Write-Host "New: $($changes.Summary.NewCount)"
Write-Host "Updated: $($changes.Summary.UpdatedCount)"
Write-Host "Removed: $($changes.Summary.RemovedCount)"
```

### Run Example Script

```powershell
./Example-ChangeDetection.ps1 -CsvPath './data/examples/fs_powerschool_nonapi_report/students_example.csv'
```

## What's Included

### Module Functions
- **`Connect-PowerSchool`** - Authenticate with PowerSchool API using OAuth 2.0
- **`Get-PowerSchoolStudent`** - Retrieve student data from PowerSchool API
- **`Invoke-PowerQuery`** - Execute PowerSchool PowerQueries for custom data retrieval
- **`Import-FSCsv`** - Parse Final Site Enrollment CSV files
- **`Compare-PSStudent`** - Detect changes between CSV and PowerSchool student data
- **`Compare-PSContact`** - Detect changes in contacts, emails, phones, addresses, and relationships

### Data Files
- Example CSVs under `data/examples/`
- CSV templates in `config/templates/`

### Utility Scripts
- **`Example-ChangeDetection.ps1`** - Complete student change detection workflow example
- **`Example-ContactChangeDetection.ps1`** - Complete contact change detection workflow with emails, phones, addresses, and relationships
- **`Filter-ParentsByStudentExampleFile.ps1`** - Filter parent rows by student list
- **`Anonymize-ParentsExampleFile.ps1`** - Anonymize sample data for sharing/tests

### Tests
- Comprehensive Pester tests for all functions
- Run tests: `Invoke-Pester -Path ./fsenrollment-pssync/tests/`

## Documentation

- **[Secure Credential Management](docs/Secure-Credential-Management.md)** - 🔒 Comprehensive guide to secure credential handling
- **[PowerSchool Change Detection Usage Guide](docs/PowerSchool-ChangeDetection-Usage.md)** - Detailed usage examples for student and contact change detection
- **[Documentation Overview](docs/readme.md)** - Full documentation structure
- **[CSV Parsing Examples](docs/CSV-Parsing-Examples.md)** - CSV import examples
- **[Invoke-PowerQuery Examples](docs/Invoke-PowerQuery-Examples.md)** - PowerQuery usage examples
- **PowerSchool API Spec**: `docs/powerschool_api.yaml` (OpenAPI)
- **PowerSchool API Plugin**: `docs/powerschool api plugin/plugin.xml`
- **PowerQuery Documentation**: `docs/powerschool api plugin/*.named_queries.md`

## Requirements

- PowerShell 7.0 or higher
- PowerSchool API credentials (Client ID and Secret)
- PowerSchool API plugin installed with appropriate permissions
- Pester 5.0+ for running tests

## Configuration

### Secure Credential Management (Recommended)

Use the secure credential system to prevent credential leaks. `Connect-PowerSchool` now automatically loads credentials from the `.env` file:

```powershell
# 1. Create .env file from template
Copy-Item config\.env.example config\.env
# Edit config\.env with your actual credentials

# 2. Import the module and connect (credentials loaded automatically from .env)
Import-Module ./fsenrollment-pssync/FSEnrollment-PSSync.psd1
Connect-PowerSchool  # No parameters needed - uses .env file!

# Alternative: Manually import credentials for other uses
$credentials = Import-EnvironmentCredentials -ClearEnvironmentVariables
```

**Credential Loading Priority:**
1. Explicit parameters (highest priority)
2. `.env` file credentials
3. Environment variables  
4. Interactive prompts (lowest priority)

See **[Secure Credential Management](docs/Secure-Credential-Management.md)** for complete details.

### Environment Variables (Alternative)

```powershell
$env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
$env:PowerSchool_ClientID = 'your-client-id'
$env:PowerSchool_ClientSecret = 'your-client-secret'
```

### Configuration File (Legacy)

Copy `config/config.example.psd1` to `config/config.psd1` and customize settings.

## Security

- **SecureString encryption** - Credentials stored as SecureStrings in memory
- **Environment variable clearing** - Automatically clear environment variables after loading to minimize exposure
- **Automated security testing** - Pester tests scan for credential leaks before commits
- **Git hooks** - Pre-commit hooks prevent accidental credential commits
- **Cross-platform** - Secure credential handling on both Linux and Windows
- **Production-ready** - VM boot scripts can load and encrypt credentials, then clear environment variables
- **Token management** - OAuth tokens automatically refreshed before expiration
- **Retry logic** - Implements exponential backoff for API calls

See **[Secure Credential Management](docs/Secure-Credential-Management.md)** for complete security documentation.

## Development Roadmap

- [x] CSV parsing and normalization
- [x] PowerSchool OAuth authentication
- [x] Student data retrieval from API
- [x] Change detection for students
- [x] Contact/parent change detection
- [x] Email address change detection
- [x] Phone number change detection
- [x] Address change detection
- [x] Relationship change detection
- [x] PowerQuery support for custom data retrieval
- [ ] Apply approved changes to PowerSchool
- [ ] Approval workflow implementation
- [ ] Scheduled sync automation
- [ ] Email notifications
- [ ] Comprehensive logging

## Testing

```powershell
# Run all tests
Invoke-Pester -Path ./fsenrollment-pssync/tests/

# Run specific test file
Invoke-Pester -Path ./fsenrollment-pssync/tests/Connect-PowerSchool.Tests.ps1 -Output Detailed

# Run security tests to check for credential leaks
Invoke-Pester -Path ./fsenrollment-pssync/tests/Security.CredentialLeak.Tests.ps1
```

### Enable Pre-commit Hooks

Automatically run security tests before each commit:

```powershell
# Configure git to use the hooks directory
git config core.hooksPath .githooks
```

See [.githooks/README.md](.githooks/README.md) for more information.

## Contributing

Please follow the PowerShell best practices outlined in `.github/copilot-instructions.md`.

## License

See [LICENSE](LICENSE) file for details.
