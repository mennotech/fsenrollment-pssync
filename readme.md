# Final Site Enrollment → PowerSchool Sync

Basic PowerShell 7+ tooling to process Final Site Enrollment CSVs and prepare/sync changes to PowerSchool SIS.

## Features

- **CSV Normalization**: Flexible parsing and normalization of CSV files from Final Site Enrollment to PowerSchool API format
  - Supports multiple CSV formats through extensible templates
  - Default template: `fs_powerschool_nonapi_report`
  - Handles students, parents, staff, courses, and enrollments
  - Automatic data type conversions and validation
- **Parent-Student Relationships**: Specialized processing for parent CSV data
  - Extracts parent/contact demographics
  - Handles multiple phone numbers per contact
  - Builds many-to-many parent-student relationships
  - Supports all relationship flags (custodial, emergency, livesWith, schoolPickup, receivesMail)
- **Module scaffold** (`fsenrollment-pssync/`) for sync cmdlets
- **Example CSVs** under `data/examples/`
- **Utility scripts**:
  - `Filter-ParentsByStudentExampleFile.ps1` to filter parent rows by student list
  - `Anonymize-ParentsExampleFile.ps1` to anonymize sample data for sharing/tests
  - `Example-CsvNormalization.ps1` to demonstrate CSV normalization
  - `Example-ParentStudentRelationships.ps1` to demonstrate parent relationship extraction

## Quick Start

### Normalize Student Data

```powershell
# Import the module
Import-Module ./fsenrollment-pssync/fsenrollment-pssync.psd1

# Normalize student data
$students = Import-Csv './data/incoming/students.csv'
$normalized = ConvertTo-NormalizedData -CsvData $students -DataType 'students'

# Export to JSON for API submission
$normalized | ConvertTo-Json -Depth 10 | Out-File './data/processed/students_normalized.json'
```

### Process Parent-Student Relationships

```powershell
# Import the module
Import-Module ./fsenrollment-pssync/fsenrollment-pssync.psd1

# Process parent CSV with multiple row types
$parents = Import-Csv './data/incoming/parents.csv'
$structured = ConvertTo-ParentStudentRelationships -CsvData $parents

# Access structured components
$structured.Contacts        # Parent demographics
$structured.PhoneNumbers    # All phone numbers (including multiples per contact)
$structured.Relationships   # Parent-student relationships with flags
```

See the [example scripts](scripts/) for more usage examples.

## Documentation

- Start here: `docs/readme.md` (documentation overview and structure)
- CSV Normalization: `config/normalization-templates/readme.md`
- PowerSchool API spec (OpenAPI): `docs/powerschool_api.yaml`
- PowerSchool API plugin XML: `docs/powerschool api plugin/plugin.xml`

## Testing

Run tests with Pester:

```powershell
# Run all tests
Invoke-Pester -Path './fsenrollment-pssync/tests/' -Output Detailed
```

## Next Steps

- ✅ Parse incoming CSVs with flexible templates
- Detect changes and stage an approval file
- Apply approved changes to PowerSchool via API with retries and logging
- Add more Pester tests and configuration wiring
