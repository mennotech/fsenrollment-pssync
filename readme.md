# Final Site Enrollment → PowerSchool Sync

PowerShell 7+ module to process Final Site Enrollment CSVs and synchronize changes with PowerSchool SIS via API.

## Features

✅ **CSV Parsing**: Import and normalize Final Site Enrollment data  
✅ **PowerSchool Authentication**: Secure OAuth 2.0 connection with automatic token renewal  
✅ **Change Detection**: Compare CSV data with PowerSchool to identify new, updated, and removed students  
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
- **`Import-FSCsv`** - Parse Final Site Enrollment CSV files
- **`Compare-PSStudent`** - Detect changes between CSV and PowerSchool data

### Data Files
- Example CSVs under `data/examples/`
- CSV templates in `config/templates/`

### Utility Scripts
- **`Example-ChangeDetection.ps1`** - Complete change detection workflow example
- **`Filter-ParentsByStudentExampleFile.ps1`** - Filter parent rows by student list
- **`Anonymize-ParentsExampleFile.ps1`** - Anonymize sample data for sharing/tests

### Tests
- Comprehensive Pester tests for all functions
- Run tests: `Invoke-Pester -Path ./fsenrollment-pssync/tests/`

## Documentation

- **[PowerSchool Change Detection Usage Guide](docs/PowerSchool-ChangeDetection-Usage.md)** - Detailed usage examples
- **[Documentation Overview](docs/readme.md)** - Full documentation structure
- **[CSV Parsing Examples](docs/CSV-Parsing-Examples.md)** - CSV import examples
- **PowerSchool API Spec**: `docs/powerschool_api.yaml` (OpenAPI)
- **PowerSchool API Plugin**: `docs/powerschool api plugin/plugin.xml`

## Requirements

- PowerShell 7.0 or higher
- PowerSchool API credentials (Client ID and Secret)
- PowerSchool API plugin installed with appropriate permissions
- Pester 5.0+ for running tests

## Configuration

### Environment Variables (Recommended)

```powershell
$env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
$env:PowerSchool_ClientID = 'your-client-id'
$env:PowerSchool_ClientSecret = 'your-client-secret'
```

### Configuration File

Copy `config/config.example.psd1` to `config/config.psd1` and customize settings.

## Security

- Credentials stored as `SecureString` in memory
- Supports environment variables and interactive secure prompts
- Never commit credentials to version control
- Token automatically refreshed before expiration
- Implements retry logic with exponential backoff

## Development Roadmap

- [x] CSV parsing and normalization
- [x] PowerSchool OAuth authentication
- [x] Student data retrieval from API
- [x] Change detection for students
- [ ] Contact/parent change detection
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
```

## Contributing

Please follow the PowerShell best practices outlined in `.github/copilot-instructions.md`.

## License

See [LICENSE](LICENSE) file for details.
