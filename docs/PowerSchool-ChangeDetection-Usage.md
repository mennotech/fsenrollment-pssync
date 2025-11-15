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

## Next Steps

After detecting changes:
1. Review the change report
2. Validate the changes are expected
3. Apply approved changes to PowerSchool using update functions (to be implemented)
4. Log all changes for audit purposes
