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

```powershell
# Automatically detect required extensions and expansions from template
$required = Get-RequiredPowerSchoolFields -TemplateMetadata $csvData.TemplateMetadata
Write-Host "Required Extensions: $($required.Extensions -join ', ')"
Write-Host "Required Expansions: $($required.Expansions -join ', ')"

# Get all students from PowerSchool with required extensions and expansions
$psStudents = Get-PowerSchoolStudent -All `
    -Extensions $required.Extensions `
    -Expansions $required.Expansions

Write-Host "Retrieved $($psStudents.Count) students from PowerSchool"

# Alternative: Manual specification
$psStudents = Get-PowerSchoolStudent -All `
    -Extensions @('u_students_extension', 'studentcorefields') `
    -Expansions @('demographics')

# Get a specific student by student number (recommended for CSV data)
$student = Get-PowerSchoolStudent -StudentNumber '123456'

# Get a specific student by DCID (PowerSchool internal ID) with expansions
# Note: DCID is not available from CSV imports, only from PowerSchool API responses
$student = Get-PowerSchoolStudent -DCID 12345 `
    -Expansions @('demographics', 'addresses', 'phones')
```

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
    
    # Step 3: Fetch PowerSchool data
    Write-Host "Fetching PowerSchool student data..." -ForegroundColor Yellow
    $psStudents = Get-PowerSchoolStudent -All -Verbose
    
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
