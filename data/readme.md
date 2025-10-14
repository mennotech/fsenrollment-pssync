# data

This directory contains CSV data files and sample data for the fsenrollmentpssync application.

## Important Notes

- **CSV files with actual student/staff data are excluded from version control**
- Only example files should be committed to the repository
- Create subdirectories for organization (incoming, processed, archive, examples)

## Directory Structure

```
data/
├── examples/           # Example CSV files (safe to commit)
├── incoming/           # Incoming files (excluded from git)
├── processed/          # Processed files (excluded from git)
└── archive/           # Archived files (excluded from git)
```

## CSV File Guidelines

### Expected Format

CSV files from Final Site Enrollment should follow a consistent format:
- UTF-8 encoding (or BOM to indicate encoding)
- Header row with column names
- Consistent delimiters (comma or specified)
- Proper quoting for fields containing delimiters or line breaks

### Example Files

Store sanitized example files in the `examples/` subdirectory:
- Use fictional data (no real student/staff information)
- Include edge cases for testing (special characters, empty fields, etc.)
- Document the expected format and required fields

### File Naming Convention

Use consistent naming for data files:
- `students_YYYY-MM-DD.csv` - Student data
- `staff_YYYY-MM-DD.csv` - Staff data
- `courses_YYYY-MM-DD.csv` - Course data
- `enrollments_YYYY-MM-DD.csv` - Enrollment data

## Security Warning

**NEVER commit files containing real student, staff, or sensitive data!**

The `.gitignore` file excludes `data/*.csv` but allows `data/examples/*.csv` for documentation purposes.

## Data Processing Workflow

1. **Incoming**: CSV files arrive in `data/incoming/`
2. **Processing**: Scripts parse and validate the CSV files
3. **Changes Detected**: Differences are logged for review
4. **Approval**: Changes are reviewed and approved
5. **Sync**: Approved changes are sent to PowerSchool API
6. **Archive**: Processed files move to `data/archive/` with timestamp

## Creating Example Files

When creating example CSV files:

```powershell
# Example: Create a sample students CSV file
$sampleStudents = @(
    [PSCustomObject]@{
        StudentId = 'S12345'
        FirstName = 'John'
        LastName = 'Doe'
        Grade = '10'
        Email = 'john.doe@example.com'
    }
    [PSCustomObject]@{
        StudentId = 'S12346'
        FirstName = 'Jane'
        LastName = 'Smith'
        Grade = '11'
        Email = 'jane.smith@example.com'
    }
)

$sampleStudents | Export-Csv -Path ./data/examples/students_example.csv -NoTypeInformation
```

## File Permissions

On Linux servers, ensure proper file permissions:
```bash
chmod 750 data/incoming
chmod 750 data/processed
chmod 750 data/archive
```
