# CSV Parsing Usage Examples

This document provides examples of how to use the CSV parsing functions to import and normalize Final Site Enrollment data.

## DateTime Format Configuration

**Note**: As of January 2026, the module supports configurable datetime formats to handle different FinalSite location settings. See [DateTime-Format-Configuration.md](DateTime-Format-Configuration.md) for detailed configuration instructions.

### Quick DateTime Format Setup

```powershell
# Configure your template for US format (MM/dd/yyyy)
DateTimeFormat = 'MM/dd/yyyy'

# Configure for International format (dd/MM/yyyy)
DateTimeFormat = 'dd/MM/yyyy'

# Configure for ISO format (yyyy-MM-dd)
DateTimeFormat = 'yyyy-MM-dd'
```

## Basic Usage

### Importing Students

```powershell
# Import the module
Import-Module fsenrollment-pssync

# Import students CSV
$studentData = Import-FSStudentsCsv -Path './students.csv'

# Access student records
$students = $studentData.Students
Write-Host "Imported $($students.Count) students"

# Work with individual students
foreach ($student in $students) {
    Write-Host "$($student.FirstName) $($student.LastName) - Grade $($student.GradeLevel)"
}
```

### Importing Parents/Contacts

```powershell
# Import parents CSV
$parentData = Import-FSParentsCsv -Path './parents.csv'

# Access different entity collections
$contacts = $parentData.Contacts
$emails = $parentData.EmailAddresses
$phones = $parentData.PhoneNumbers
$addresses = $parentData.Addresses
$relationships = $parentData.Relationships

Write-Host "Imported:"
Write-Host "  - $($contacts.Count) contacts"
Write-Host "  - $($emails.Count) email addresses"
Write-Host "  - $($phones.Count) phone numbers"
Write-Host "  - $($addresses.Count) addresses"
Write-Host "  - $($relationships.Count) student-contact relationships"
```

## Advanced Examples

### Finding Student Contacts

```powershell
# Import both students and parents
$students = Import-FSStudentsCsv -Path './students.csv'
$parents = Import-FSParentsCsv -Path './parents.csv'

# Find all contacts for a specific student
$studentNumber = '313202'
$studentRelationships = $parents.Relationships | Where-Object { $_.StudentNumber -eq $studentNumber }

foreach ($rel in $studentRelationships) {
    $contact = $parents.Contacts | Where-Object { $_.ContactIdentifier -eq $rel.ContactIdentifier }
    $email = $parents.EmailAddresses | Where-Object { $_.ContactIdentifier -eq $rel.ContactIdentifier }
    
    Write-Host "$($rel.RelationshipType): $($contact.FirstName) $($contact.LastName)"
    Write-Host "  Email: $($email.EmailAddress)"
    Write-Host "  Legal Guardian: $($rel.IsLegalGuardian)"
}
```

### Finding Multiple Phone Numbers

```powershell
$parentData = Import-FSParentsCsv -Path './parents.csv'

# Find contacts with multiple phone numbers
$contactsWithMultiplePhones = $parentData.PhoneNumbers | 
    Group-Object ContactIdentifier | 
    Where-Object { $_.Count -gt 1 }

foreach ($group in $contactsWithMultiplePhones) {
    $contact = $parentData.Contacts | Where-Object { $_.ContactIdentifier -eq $group.Name }
    Write-Host "$($contact.FirstName) $($contact.LastName) has $($group.Count) phone numbers:"
    
    $phones = $group.Group | Sort-Object PriorityOrder
    foreach ($phone in $phones) {
        Write-Host "  $($phone.PhoneType): $($phone.PhoneNumber)"
    }
}
```

### Filtering by Relationship Flags

```powershell
$parentData = Import-FSParentsCsv -Path './parents.csv'

# Find all emergency contacts
$emergencyContacts = $parentData.Relationships | Where-Object { $_.IsEmergencyContact -eq $true }

Write-Host "Emergency Contacts:"
foreach ($rel in $emergencyContacts) {
    $contact = $parentData.Contacts | Where-Object { $_.ContactIdentifier -eq $rel.ContactIdentifier }
    Write-Host "  Student $($rel.StudentNumber): $($contact.FirstName) $($contact.LastName) ($($rel.RelationshipType))"
}

# Find contacts who have custody
$custodyContacts = $parentData.Relationships | Where-Object { $_.HasCustody -eq $true }
Write-Host "`nContacts with Custody: $($custodyContacts.Count)"
```

### Excluding Contacts from Import

The parent CSV template supports excluding specific contacts from import using an optional CSV column. This is useful when certain contacts should not be synced to PowerSchool.

**Template Configuration** (in `config/templates/fs_powerschool_nonapi_report_parents.psd1`):

```powershell
@{
    # ... other configuration ...
    
    # Optional: Name of CSV column for excluding contacts
    # If omitted, the exclusion feature is disabled
    ExcludeColumnName = 'Exclude from PowerSchool Export'
}
```

**CSV Format**:

```csv
New Contact Identifier,First Name,Last Name,...,Exclude from PowerSchool Export
abc-123,John,Smith,...,false
def-456,Jane,Doe,...,true    # This contact will be excluded
def-456,,,,...,              # Additional phone row - auto-excluded
def-456,,,,...,              # Relationship row - auto-excluded
```

**Import Behavior**:

```powershell
# Import with verbose output to see excluded contacts
$parentData = Import-FSCsv -Path './parents.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_parents' `
    -Verbose

# VERBOSE: Exclude column 'Exclude from PowerSchool Export' found in CSV, checking for excluded contacts
# VERBOSE: Marking contact for exclusion: def-456 (Jane Doe)
# VERBOSE: Added contact: John Smith (abc-123)
# VERBOSE: Skipping all rows for excluded contact def-456

Write-Host "Imported $($parentData.Contacts.Count) contacts"
# Note: Excluded contacts and all their related data (emails, phones, addresses, relationships) are not imported
```

**Backward Compatibility**:

The exclude feature is optional and backward compatible:
- If `ExcludeColumnName` is not configured in the template, all contacts are imported
- If the column exists in the template but not in the CSV, all contacts are imported
- Only when both the template configuration and CSV column exist are exclusions applied

**Customizing the Column Name**:

Different environments can use different column names by customizing the template:

```powershell
# In your custom template copy
ExcludeColumnName = 'Skip Import'  # Use your CSV's column name
```

### Exporting Normalized Data

```powershell
# Import and normalize data
$studentData = Import-FSStudentsCsv -Path './students.csv'
$parentData = Import-FSParentsCsv -Path './parents.csv'

# Export to JSON for processing
$studentData.Students | ConvertTo-Json -Depth 10 | Out-File -FilePath './normalized-students.json'
$parentData.Contacts | ConvertTo-Json -Depth 10 | Out-File -FilePath './normalized-contacts.json'
$parentData.Relationships | ConvertTo-Json -Depth 10 | Out-File -FilePath './normalized-relationships.json'

Write-Host "Normalized data exported to JSON files"
```

### Data Validation

```powershell
$studentData = Import-FSStudentsCsv -Path './students.csv' -Verbose

# Validate data
$invalidDOB = $studentData.Students | Where-Object { $_.DOB -gt (Get-Date) }
if ($invalidDOB.Count -gt 0) {
    Write-Warning "Found $($invalidDOB.Count) students with future birth dates"
}

# Check for missing required fields
$missingLastName = $studentData.Students | Where-Object { [string]::IsNullOrWhiteSpace($_.LastName) }
if ($missingLastName.Count -gt 0) {
    Write-Warning "Found $($missingLastName.Count) students without last names"
}

Write-Host "Validation complete"
```

## Working with PSNormalizedData

The `PSNormalizedData` class contains strongly-typed collections for all entity types:

```powershell
# Create a new normalized data container
$normalizedData = [PSNormalizedData]::new()

# Add entities to the collections
$normalizedData.Students.Add($student)
$normalizedData.Contacts.Add($contact)
$normalizedData.Relationships.Add($relationship)

# Access counts
Write-Host "Total entities: $($normalizedData.Students.Count + $normalizedData.Contacts.Count)"
```

## Verbose Output

Use the `-Verbose` parameter to see detailed parsing information:

```powershell
Import-FSStudentsCsv -Path './students.csv' -Verbose
Import-FSParentsCsv -Path './parents.csv' -Verbose
```

This will show:
- Number of rows parsed
- Individual records being processed
- Any data type conversion issues
- Summary statistics

## Error Handling

```powershell
try {
    $studentData = Import-FSStudentsCsv -Path './students.csv'
    Write-Host "Successfully imported $($studentData.Students.Count) students"
}
catch {
    Write-Error "Failed to import students: $_"
    # Handle error appropriately
}
```

## Performance Tips

For large CSV files:
1. Import data once and cache the result
2. Use filtering before iteration
3. Consider processing in batches for very large datasets
4. Use `.Where()` method instead of `Where-Object` for better performance on large collections

```powershell
# Efficient filtering
$parentData = Import-FSParentsCsv -Path './parents.csv'
$mothers = $parentData.Relationships.Where({ $_.RelationshipType -eq 'Mother' })
```
