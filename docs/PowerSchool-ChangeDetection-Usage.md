# PowerSchool Change Detection Usage Examples

This document demonstrates how to use the PowerSchool change detection functionality.

## Prerequisites

1. PowerSchool API credentials (Client ID and Client Secret)
2. PowerSchool instance URL
3. Properly configured PowerSchool API plugin with appropriate permissions

## Basic Workflow

### 1. Connect to PowerSchool

```powershell
# Import the module
Import-Module FSEnrollment-PSSync

# Method 1: Using environment variables (recommended)
$env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
$env:PowerSchool_ClientID = 'your-client-id'
$env:PowerSchool_ClientSecret = 'your-client-secret'

Connect-PowerSchool

# Method 2: Using parameters with SecureString
$clientSecret = Read-Host -Prompt "Enter Client Secret" -AsSecureString
Connect-PowerSchool -BaseUrl 'https://your-instance.powerschool.com' `
    -ClientId 'your-client-id' `
    -ClientSecret $clientSecret

# Method 3: Interactive (will prompt for missing credentials)
Connect-PowerSchool
```

### 2. Import CSV Data

```powershell
# Import student data from CSV
$csvData = Import-FSCsv -Path './data/students.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_students'

Write-Host "Imported $($csvData.Students.Count) students from CSV"
```

### 3. Fetch PowerSchool Data

#### **RECOMMENDED APPROACH**

The best practice is to let PowerSchell automatically detect which API extensions and expansions are needed based on your template configuration. This ensures all necessary data is retrieved for accurate comparison without manual configuration.

**Method 1: Using `-TemplateMetadata` (BEST - use when you already have CSV data)**

This is the most common pattern for change detection workflows:

```powershell
# Step 1: Import CSV data
$csvData = Import-FSCsv -Path './data/students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'

# Step 2: Fetch PowerSchool data with automatic field detection
$psStudents = Get-PowerSchoolStudent -All -TemplateMetadata $csvData.TemplateMetadata

# Step 3: Compare
$changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents

Write-Host "Retrieved $($psStudents.Count) students from PowerSchool"
```

✅ **Advantages:**
- Automatically detects required extensions and expansions from template
- Uses the same template metadata for both import and retrieval
- Guarantees consistency between CSV parsing and PowerSchool API calls
- Zero configuration needed

**Method 2: Using `-TemplateName` (GOOD - use when fetching data without CSV import)**

Use this when you need PowerSchool data but don't have a CSV file yet:

```powershell
# Loads template and automatically detects required fields
$psStudents = Get-PowerSchoolStudent -All -TemplateName 'fs_powerschool_nonapi_report_students'

Write-Host "Retrieved $($psStudents.Count) students from PowerSchool"
```

✅ **Advantages:**
- No need to import CSV first
- Useful for data exploration or one-time pulls
- Still uses template configuration for consistency

#### **Alternative Approaches (NOT RECOMMENDED)**

These methods work but add unnecessary complexity and maintenance burden:

❌ Manual detection using Get-RequiredPowerSchoolFields

```powershell
# This works but is unnecessary - Get-PowerSchoolStudent already does this internally
$csvData = Import-FSCsv -Path './data/students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
$required = Get-RequiredPowerSchoolFields -TemplateMetadata $csvData.TemplateMetadata
Write-Host "Required Extensions: $($required.Extensions -join ', ')"
Write-Host "Required Expansions: $($required.Expansions -join ', ')"
$psStudents = Get-PowerSchoolStudent -All `
    -Extensions $required.Extensions `
    -Expansions $required.Expansions
```

**Why not recommended:** Adds extra steps when `Get-PowerSchoolStudent` already performs this detection internally.

❌ Manual specification

```powershell
# Hardcoding extensions and expansions - error-prone and not maintainable
$psStudents = Get-PowerSchoolStudent -All `
    -Extensions @('u_students_extension', 'studentcorefields') `
    -Expansions @('demographics', 'addresses')
```

**Why not recommended:** 
- Requires manual updates when template changes
- Error-prone - easy to miss required fields
- Breaks consistency with template configuration
- Not maintainable for multiple templates

#### **Single Student Retrieval**

```powershell
# Get a specific student by student number (recommended for CSV imports)
$student = Get-PowerSchoolStudent -StudentNumber '123456'

# Get a specific student by DCID with specific expansions
# Note: DCID is PowerSchool's internal ID, not available from CSV imports
$student = Get-PowerSchoolStudent -DCID 12345 `
    -Expansions @('demographics', 'addresses', 'phones')
```

#### **How Automatic Detection Works**

When you use `-TemplateMetadata` or `-TemplateName`, `Get-PowerSchoolStudent` automatically:

1. Parses all `PowerSchoolAPIField` mappings in your template
2. Identifies extension fields (format: `extension.table_name.field`)
3. Identifies expansion fields (format: `@expansion_name.field`)
4. Merges detected fields with any manually specified ones (no duplicates)
5. Retrieves data with all required API features enabled

This ensures **all necessary data is retrieved for accurate comparison** without manual configuration.

### 4. Compare and Detect Changes

```powershell
# Compare CSV data with PowerSchool data
# Note: This only detects new and updated students, NOT removed students
$changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents

# Display summary
Write-Host "`nChange Summary:" -ForegroundColor Yellow
Write-Host "  New students: $($changes.Summary.NewCount)" -ForegroundColor Green
Write-Host "  Updated students: $($changes.Summary.UpdatedCount)" -ForegroundColor Cyan
Write-Host "  Unchanged students: $($changes.Summary.UnchangedCount)" -ForegroundColor Gray

# Review new students
if ($changes.New.Count -gt 0) {
    Write-Host "`nNew Students:" -ForegroundColor Green
    foreach ($new in $changes.New) {
        $student = $new.Student
        Write-Host "  $($student.StudentNumber): $($student.FirstName) $($student.LastName) - Grade $($student.GradeLevel)"
    }
}

# Review updated students
if ($changes.Updated.Count -gt 0) {
    Write-Host "`nUpdated Students:" -ForegroundColor Cyan
    foreach ($updated in $changes.Updated) {
        Write-Host "  Student: $($updated.MatchKey)"
        foreach ($change in $updated.Changes) {
            Write-Host "    $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
        }
    }
}
```

## Complete Example Script

```powershell
#Requires -Version 7.0

# Import the module
Import-Module FSEnrollment-PSSync

try {
    # Step 1: Connect to PowerSchool
    Write-Host "Connecting to PowerSchool..." -ForegroundColor Yellow
    Connect-PowerSchool
    
    # Step 2: Import CSV data
    Write-Host "Importing CSV data..." -ForegroundColor Yellow
    $csvData = Import-FSCsv -Path './data/students.csv' `
        -TemplateName 'fs_powerschool_nonapi_report_students' `
        -Verbose
    
    # Step 3: Fetch PowerSchool data (automatically detects required fields from template)
    Write-Host "Fetching PowerSchool student data..." -ForegroundColor Yellow
    $psStudents = Get-PowerSchoolStudent -All `
        -TemplateMetadata $csvData.TemplateMetadata `
        -Verbose
    
    # Step 4: Compare and detect changes
    Write-Host "Comparing data..." -ForegroundColor Yellow
    $changes = Compare-PSStudent -CsvData $csvData `
        -PowerSchoolData $psStudents `
        -Verbose
    
    # Step 5: Display results
    Write-Host "`n=== Change Detection Results ===" -ForegroundColor Green
    Write-Host "Total in CSV: $($changes.Summary.TotalInCsv)"
    Write-Host "Total in PowerSchool: $($changes.Summary.TotalInPowerSchool)"
    Write-Host "New: $($changes.Summary.NewCount)" -ForegroundColor Green
    Write-Host "Updated: $($changes.Summary.UpdatedCount)" -ForegroundColor Cyan
    Write-Host "Unchanged: $($changes.Summary.UnchangedCount)" -ForegroundColor Gray
    
    # Export changes to JSON for review/approval
    $changesJson = $changes | ConvertTo-Json -Depth 10
    $changesJson | Out-File -FilePath './data/pending_changes.json' -Encoding UTF8
    Write-Host "`nChanges exported to ./data/pending_changes.json" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
```

## Token Management

The PowerSchool connection automatically manages token expiration and renewal:

```powershell
# Connect once
Connect-PowerSchool

# Make multiple API calls - token will be automatically refreshed if needed
$students1 = Get-PowerSchoolStudent -StudentNumber '111111'
$students2 = Get-PowerSchoolStudent -StudentNumber '222222'
$students3 = Get-PowerSchoolStudent -StudentNumber '333333'

# Force reconnection if needed
Connect-PowerSchool -Force
```

## Error Handling

The functions include built-in retry logic with exponential backoff:

```powershell
# API calls will automatically retry on:
# - Rate limiting (429 status)
# - Server errors (5xx status)
# - Network timeouts

# Configure retry behavior (in Invoke-PowerSchoolApiRequest calls)
# Default: 3 retries with 5-second initial delay, exponential backoff
```

## Security Best Practices

1. **Use Environment Variables**: Store credentials in environment variables, not in scripts
2. **Avoid Hardcoding Secrets**: Never commit credentials to version control
3. **Use SecureString**: When passing credentials programmatically, use SecureString
4. **Limit Permissions**: Use PowerSchool API plugins with minimum required permissions
5. **Audit Logs**: Review PowerSchool API access logs regularly

## Contact Comparison (First Step)

The module now supports comparing contact data from CSV against PowerSchool person records using the `com.fsenrollment.dats.person` PowerQuery.

### Basic Contact Comparison Workflow

```powershell
# Step 1: Import contact data from CSV
$csvData = Import-FSCsv -Path './data/contacts.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_parents'

Write-Host "Imported $($csvData.Contacts.Count) contacts from CSV"

# Step 2: Fetch person data from PowerSchool using PowerQuery
$personData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords

Write-Host "Retrieved $($personData.RecordCount) person records from PowerSchool"

# Step 3: Compare CSV contacts with PowerSchool person data
$contactChanges = Compare-PSContact -CsvData $csvData `
    -PowerSchoolData $personData.Records `
    -Verbose

# Step 4: Display summary
Write-Host "`nContact Change Summary:" -ForegroundColor Yellow
Write-Host "  New contacts: $($contactChanges.Summary.NewCount)" -ForegroundColor Green
Write-Host "  Updated contacts: $($contactChanges.Summary.UpdatedCount)" -ForegroundColor Cyan
Write-Host "  Unchanged contacts: $($contactChanges.Summary.UnchangedCount)" -ForegroundColor Gray

# Review updated contacts
if ($contactChanges.Updated.Count -gt 0) {
    Write-Host "`nUpdated Contacts:" -ForegroundColor Cyan
    foreach ($updated in $contactChanges.Updated) {
        Write-Host "  Contact ID: $($updated.MatchKey)"
        foreach ($change in $updated.Changes) {
            Write-Host "    $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
        }
    }
}
```

### What Compare-PSContact Checks

The `Compare-PSContact` function checks the following data:

**PSContact Fields** (always checked):
- **FirstName** (maps to `person_firstname`)
- **MiddleName** (maps to `person_middlename`)
- **LastName** (maps to `person_lastname`)
- **Gender** (maps to `person_gender_code`)
- **Employer** (maps to `person_employer`)

**Email Addresses** (optional - checked if PowerSchoolEmailData is provided):
- Email address
- Email type

## DateTime Format Configuration

The FSEnrollment-PSSync module supports configurable datetime formats to handle different FinalSite location settings and mixed datetime formats within CSV files.

### Template-Level DateTime Format

Configure a default datetime format for the entire template:

```powershell
@{
    # Default datetime format for the template (applies to all datetime columns)
    DateTimeFormat = 'dd/MM/yyyy'  # e.g., 31/12/2023 for UK format
    
    # Column mappings...
    ColumnMappings = @(
        # datetime columns will use the template DateTimeFormat by default
    )
}
```

### Per-Column DateTime Format

For CSV files with mixed datetime formats, specify formats for individual columns:

```powershool
@{
    # Template-level format (fallback for columns without specific format)
    DateTimeFormat = 'dd/MM/yyyy'
    
    ColumnMappings = @(
        @{
            CsvColumn = 'DOB'
            PropertyName = 'DOB'
            DataType = 'datetime'
            DateTimeFormat = 'dd/MM/yyyy'  # UK format: 31/12/1999
        },
        @{
            CsvColumn = 'EntryDate'
            PropertyName = 'EntryDate' 
            DataType = 'datetime'
            DateTimeFormat = 'M/d/yy'      # US short format: 12/31/99
        },
        @{
            CsvColumn = 'ExitDate'
            PropertyName = 'ExitDate'
            DataType = 'datetime'
            DateTimeFormat = 'M/d/yyyy'    # US long format: 12/31/1999
        }
    )
}
```

### Format Precedence

The datetime parsing uses this precedence:
1. **Column-specific format**: If `DateTimeFormat` is specified in the column mapping
2. **Template-level format**: If `DateTimeFormat` is specified at the template level
3. **Auto-parsing**: Falls back to PowerShell's default `[DateTime]::Parse()` method

### Common DateTime Formats

| Format | Example | Description |
|--------|---------|-------------|
| `dd/MM/yyyy` | 31/12/2023 | Day/Month/Year (UK/EU format) |
| `MM/dd/yyyy` | 12/31/2023 | Month/Day/Year (US format) |
| `M/d/yyyy` | 12/31/2023 | Month/Day/Year (no leading zeros) |
| `M/d/yy` | 12/31/23 | Month/Day/Year (2-digit year) |
| `yyyy-MM-dd` | 2023-12-31 | ISO format |
| `dd-MMM-yyyy` | 31-Dec-2023 | Day-Month-Year with month name |

### Error Handling

When datetime parsing fails:
- A warning is displayed showing the failed value and expected format
- The datetime field is set to `DateTime.MinValue` (0001-01-01)
- Processing continues with other records

Example warning:
```
WARNING: Failed to convert '31/12/1999' to datetime using column format 'MM/dd/yyyy' for property DOB
```
- Priority order
- Primary status

**Phone Numbers** (optional - checked if PowerSchoolPhoneData is provided):
- Phone number (with normalization for different formats)
- Phone type
- Priority order
- Preferred status
- SMS capability

**Addresses** (optional - checked if PowerSchoolAddressData is provided):
- Street address
- Line two
- Unit
- City
- State
- Postal code
- Address type
- Priority order

**Relationships** (optional - checked if PowerSchoolRelationshipData is provided):
- Contact priority order
- Relationship type
- Relationship note
- Custody status
- Lives with flag
- School pickup permission
- Emergency contact flag
- Receives mail flag

### Extended Contact Comparison with All Data

For comprehensive change detection including emails, phones, addresses, and relationships:

```powershell
# Step 1: Import contact data from CSV
$csvData = Import-FSCsv -Path './data/contacts.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_parents'

# Step 2: Fetch all PowerSchool data
$personData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
$emailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
$phoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$addressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$relationshipData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords

# Step 3: Load template configuration
$templateConfig = Import-PowerShellDataFile './config/templates/fs_powerschool_nonapi_report_parents.psd1'

# Step 4: Compare with all data types
$contactChanges = Compare-PSContact -CsvData $csvData `
    -PowerSchoolData $personData.Records `
    -PowerSchoolEmailData $emailData.Records `
    -PowerSchoolPhoneData $phoneData.Records `
    -PowerSchoolAddressData $addressData.Records `
    -PowerSchoolRelationshipData $relationshipData.Records `
    -TemplateConfig $templateConfig `
    -Verbose

# Step 5: Display comprehensive results
Write-Host "`nContact Change Summary:" -ForegroundColor Yellow
Write-Host "  Total in CSV: $($contactChanges.Summary.TotalInCsv)"
Write-Host "  Total in PowerSchool: $($contactChanges.Summary.TotalInPowerSchool)"
Write-Host "  New contacts: $($contactChanges.Summary.NewCount)" -ForegroundColor Green
Write-Host "  Updated contacts: $($contactChanges.Summary.UpdatedCount)" -ForegroundColor Cyan
Write-Host "  Unchanged contacts: $($contactChanges.Summary.UnchangedCount)" -ForegroundColor Gray

# Review updated contacts with all change types
if ($contactChanges.Updated.Count -gt 0) {
    Write-Host "`nUpdated Contacts:" -ForegroundColor Cyan
    foreach ($updated in $contactChanges.Updated) {
        Write-Host "  Contact ID: $($updated.MatchKey)"
        
        # Basic field changes
        if ($updated.Changes -and $updated.Changes.Count -gt 0) {
            foreach ($change in $updated.Changes) {
                Write-Host "    $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
            }
        }
        
        # Email changes
        if ($updated.EmailChanges) {
            Write-Host "    Emails: +$($updated.EmailChanges.Added.Count) ~$($updated.EmailChanges.Modified.Count) -$($updated.EmailChanges.Removed.Count)"
        }
        
        # Phone changes
        if ($updated.PhoneChanges) {
            Write-Host "    Phones: +$($updated.PhoneChanges.Added.Count) ~$($updated.PhoneChanges.Modified.Count) -$($updated.PhoneChanges.Removed.Count)"
        }
        
        # Address changes
        if ($updated.AddressChanges) {
            Write-Host "    Addresses: +$($updated.AddressChanges.Added.Count) ~$($updated.AddressChanges.Modified.Count) -$($updated.AddressChanges.Removed.Count)"
        }
        
        # Relationship changes
        if ($updated.RelationshipChanges) {
            Write-Host "    Relationships: +$($updated.RelationshipChanges.Added.Count) ~$($updated.RelationshipChanges.Modified.Count) -$($updated.RelationshipChanges.Removed.Count)"
        }
    }
}
```

### Contact Comparison Notes

- The comparison matches contacts using ContactID by default (which maps to `person_id` in PowerSchool), but can be configured to use ContactIdentifier through the TemplateConfig or MatchOn parameter.
- Only contacts related to enrolled students are returned by the PowerQuery
- The function identifies new contacts, updated contacts, and unchanged contacts
- Removed contacts (in PowerSchool but not in CSV) are NOT detected by this function
- Email addresses are matched by normalized email address (case-insensitive)
- Phone numbers are normalized for comparison (different formats of the same number are matched)
- Addresses are matched by composite key (street + city + postal code)
- Relationships are matched by person + student combination (ContactIdentifier + StudentNumber)
- All entity comparisons (email, phone, address, relationship) detect additions, modifications, and removals

### Available PowerQueries for Contact Data

The following PowerQueries are available for comprehensive contact data retrieval:

- **com.fsenrollment.dats.person** - Basic person information
- **com.fsenrollment.dats.person.email** - Email addresses with type, priority, and primary status
- **com.fsenrollment.dats.person.phone** - Phone numbers with type, priority, SMS capability
- **com.fsenrollment.dats.person.address** - Addresses with full components
- **com.fsenrollment.dats.person.relationship** - Student-contact relationships with flags

## Next Steps

After detecting changes:
1. Review the change report
2. Validate the changes are expected
3. Apply approved changes to PowerSchool using update functions (to be implemented)
4. Log all changes for audit purposes
