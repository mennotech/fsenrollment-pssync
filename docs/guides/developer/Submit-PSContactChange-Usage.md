# Submit-PSContactChange Usage Examples

This document demonstrates how to use the `Submit-PSContactChange` function to apply contact changes (demographics, emails, phones, addresses, and relationships) detected by `Compare-PSContact` to PowerSchool.

## Prerequisites

1. PowerSchool API credentials configured
2. Active PowerSchool connection (`Connect-PowerSchool`)
3. Changes detected using `Compare-PSContact` (either in memory or exported to JSON)
4. **IMPORTANT**: PowerQuery plugin version 1.1.9+ required for email/phone/address association IDs (see [PowerQuery Association IDs Update](../../updates/PowerQuery-Association-IDs-Update.md))

## Basic Workflow

### 1. Complete Workflow: Detect and Apply Changes

```powershell
# Import the module
Import-Module FSEnrollment-PSSync

# Connect to PowerSchool
Connect-PowerSchool

# Import CSV data
$csvData = Import-FSCsv -Path './data/contacts.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_parents'

# Get PowerSchool data
$psPersonData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
$psEmailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
$psPhoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$psAddressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$psRelationshipData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords

# Load template configuration
$templateConfig = Import-PowerShellDataFile './config/templates/fs_powerschool_nonapi_report_parents.psd1'

# Compare to detect changes
$changes = Compare-PSContact `
    -CsvData $csvData `
    -PowerSchoolData $psPersonData.Records `
    -PowerSchoolEmailData $psEmailData.Records `
    -PowerSchoolPhoneData $psPhoneData.Records `
    -PowerSchoolAddressData $psAddressData.Records `
    -PowerSchoolRelationshipData $psRelationshipData.Records `
    -TemplateConfig $templateConfig

# Review changes
Write-Host "Found:"
Write-Host "  New contacts: $($changes.Summary.NewCount)"
Write-Host "  Updated contacts: $($changes.Summary.UpdatedCount)"
Write-Host "  Unchanged contacts: $($changes.Summary.UnchangedCount)"

# Apply changes to PowerSchool
$result = Submit-PSContactChange -Changes $changes

# Review results
Write-Host "`nResults:"
Write-Host "  New contacts created: $($result.NewContactsApplied)"
Write-Host "  Contacts updated: $($result.UpdatedContactsApplied)"
Write-Host "  Total applied: $($result.Summary.TotalApplied)"

if ($result.FailedChanges.Count -gt 0) {
    Write-Warning "Failed to apply $($result.FailedChanges.Count) changes"
    $result.FailedChanges | Format-Table MatchKey, Type, Error -Wrap
}
```

### 2. Review and Approve Workflow (Recommended)

```powershell
# Step 1: Detect changes and export to JSON for review
$changes = Compare-PSContact `
    -CsvData $csvData `
    -PowerSchoolData $psPersonData.Records `
    -PowerSchoolEmailData $psEmailData.Records `
    -PowerSchoolPhoneData $psPhoneData.Records `
    -PowerSchoolAddressData $psAddressData.Records `
    -PowerSchoolRelationshipData $psRelationshipData.Records `
    -TemplateConfig $templateConfig

# Export to JSON
$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmm'
$outputPath = "./data/pending/${timestamp}-contact-changes.json"
$changes | ConvertTo-Json -Depth 10 | Out-File $outputPath

Write-Host "Changes exported to $outputPath for review"

# Step 2: Manually review the JSON file
# Open and review the generated JSON file to verify all changes are correct

# Step 3: Apply changes after approval
$result = Submit-PSContactChange -JsonPath $outputPath
```

### 3. Testing with Live Data (Limited Changes)

When first testing with live PowerSchool data, use the `-Limit` parameter to apply only a few changes:

```powershell
# Step 1: Preview with WhatIf and Verbose to see exactly what would happen
Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -Limit 5 -WhatIf -Verbose

# Step 2: Review the detailed output showing:
#   - Exact API endpoints for each operation
#   - Field-by-field changes (demographics, emails, phones, addresses)
#   - Complete JSON payloads
#   - PowerSchool field mappings

# Step 3: If everything looks correct, apply the limited test batch
$testResult = Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -Limit 5

# Step 4: Review the results carefully
Write-Host "Test Results:"
Write-Host "  New contacts created: $($testResult.NewContactsApplied)"
Write-Host "  Contacts updated: $($testResult.UpdatedContactsApplied)"
Write-Host "  Total applied: $($testResult.Summary.TotalApplied)"
Write-Host "  Failed: $($testResult.Summary.TotalFailed)"

if ($testResult.FailedChanges.Count -gt 0) {
    Write-Warning "Some changes failed - review before proceeding"
    $testResult.FailedChanges | Format-Table Type, MatchKey, Error -Wrap
}
```

**Important Notes on Using -Limit:**

- The function processes changes in order: **New contacts first, then Updates**
- Using `-Limit 5` with 3 new contacts and 10 updates will process all 3 new contacts + 2 updates
- For batch processing large files, use `-Skip` and `-Limit` together

## Advanced Usage

### Batch Processing Large Change Files

For large change files, process in batches to control load and allow for review between batches:

```powershell
$changeFile = './data/pending/2026-02-18-1234-contact-changes.json'
$batchSize = 25

# Batch 1: Process first 25 changes
Submit-PSContactChange -JsonPath $changeFile -Skip 0 -Limit $batchSize

# Batch 2: Process next 25 changes
Submit-PSContactChange -JsonPath $changeFile -Skip 25 -Limit $batchSize

# Batch 3: Process next 25 changes
Submit-PSContactChange -JsonPath $changeFile -Skip 50 -Limit $batchSize

# Continue for remaining batches...
```

**Automated Batch Processing:**

```powershell
$changeFile = './data/pending/2026-02-18-1234-contact-changes.json'
$batchSize = 25
$totalProcessed = 0
$allResults = @()

# Load changes to get total count
$changes = Get-Content $changeFile | ConvertFrom-Json
$totalChanges = $changes.New.Count + $changes.Updated.Count

Write-Host "Processing $totalChanges changes in batches of $batchSize..."

while ($totalProcessed -lt $totalChanges) {
    $batchNumber = [Math]::Floor($totalProcessed / $batchSize) + 1
    Write-Host "`n=== Batch $batchNumber (Skip: $totalProcessed, Limit: $batchSize) ==="
    
    $result = Submit-PSContactChange -JsonPath $changeFile -Skip $totalProcessed -Limit $batchSize
    $allResults += $result
    
    Write-Host "Batch Results: Applied $($result.Summary.TotalApplied), Failed $($result.Summary.TotalFailed)"
    
    $totalProcessed += $result.Summary.TotalProcessed
    
    # Optional: Pause between batches
    if ($totalProcessed -lt $totalChanges) {
        Start-Sleep -Seconds 2
    }
}

# Summary
$totalApplied = ($allResults | Measure-Object -Property NewContactsApplied -Sum).Sum + `
                ($allResults | Measure-Object -Property UpdatedContactsApplied -Sum).Sum
$totalFailed = ($allResults.FailedChanges | Measure-Object).Count

Write-Host "`n=== Final Summary ==="
Write-Host "Total Changes Applied: $totalApplied"
Write-Host "Total Failures: $totalFailed"
```

### WhatIf Mode - Preview Without Applying

Use `-WhatIf` to preview all changes without connecting to PowerSchool:

```powershell
# Preview mode - no connection needed
Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -WhatIf

# Preview with verbose details
Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' -WhatIf -Verbose
```

**WhatIf mode shows:**
- Which contacts would be created or updated
- Demographics fields being changed
- Email addresses being added/modified/removed
- Phone numbers being added/modified/removed
- Addresses being added/modified/removed
- Relationships being added/modified/removed
- Exact API endpoints and payloads (with -Verbose)

### Custom Retry Configuration

For unreliable network connections, adjust retry settings:

```powershell
# Increase retries and delay for slow/unreliable connections
Submit-PSContactChange -JsonPath './data/pending/contact-changes.json' `
    -MaxRetries 5 `
    -RetryDelaySeconds 10
```

## Understanding Contact Changes

### Change Types Supported

#### 1. Demographics (Phase 1)
- firstName, middleName, lastName
- prefix, suffix
- gender
- employer

#### 2. Email Addresses (Phase 2)
- **Add**: New email addresses
- **Modify**: Changes to email address or primary status
- **Remove**: Email addresses no longer in CSV

#### 3. Phone Numbers (Phase 2)
- **Add**: New phone numbers
- **Modify**: Changes to number, type, sequence, preferred status, or SMS capability
- **Remove**: Phone numbers no longer in CSV

#### 4. Addresses (Phase 2)
- **Add**: New addresses
- **Modify**: Changes to street, city, state, postal code, or address type
- **Remove**: Addresses no longer in CSV

#### 5. Student Relationships (Phase 3)
- **Add**: New student-contact relationships
- **Modify**: Changes to relationship type, custody, pickup rights, emergency contact status, etc.
- **Remove**: Relationships no longer in CSV

### API Endpoints Used

| Operation | Endpoint | Method |
|-----------|----------|--------|
| Create new contact | `/ws/contacts/contact` | POST |
| Update demographics | `/ws/contacts/{contactId}/demographics` | PUT |
| Update emails | `/ws/contacts/{contactId}` | PUT |
| Update phones | `/ws/contacts/{contactId}` | PUT |
| Update addresses | `/ws/contacts/{contactId}` | PUT |
| Update relationships | `/ws/contacts/{contactId}` | PUT |

## Troubleshooting

### Common Issues

#### 1. TemplateMetadata Missing

**Error**: "TemplateMetadata not found in Changes object"

**Solution**: Ensure you're using the output from `Compare-PSContact`, which includes TemplateMetadata:

```powershell
# Correct - includes template configuration
$changes = Compare-PSContact -CsvData $csvData `
    -PowerSchoolData $psData `
    -TemplateConfig $templateConfig
```

#### 2. Contact ID Not Found for Updates

**Error**: "PowerSchool contact person_id (ContactID) not found"

**Solution**: The contact exists in CSV but not in PowerSchool. This is actually a new contact, not an update. Regenerate changes after ensuring PowerSchool data is current.

#### 3. API Validation Errors

**Error**: "PowerSchool API validation error: Field 'emailAddress': ..."

**Solution**: 
- Review the error message for the specific field causing issues
- Check CSV data for that contact
- Verify field mappings in template configuration
- Use `-WhatIf -Verbose` to preview the exact payload being sent

#### 4. Association ID Errors (Emails/Phones/Addresses)

**Error**: "Missing association ID for email/phone/address update"

**Solution**: 
- Ensure PowerQuery plugin version 1.1.9+ is installed (see [PowerQuery Association IDs Update](../../updates/PowerQuery-Association-IDs-Update.md))
- Re-query PowerSchool data after plugin update
- Verify association ID columns are present in PowerQuery results

### Validation Before Applying

Always validate changes before applying to production:

```powershell
# 1. Check change counts
Write-Host "New: $($changes.Summary.NewCount)"
Write-Host "Updated: $($changes.Summary.UpdatedCount)"

# 2. Review a sample of changes
$changes.New | Select-Object -First 3 | Format-List
$changes.Updated | Select-Object -First 3 | Format-List

# 3. Export and manually review
$changes | ConvertTo-Json -Depth 10 | Out-File './review.json'

# 4. Test with WhatIf
Submit-PSContactChange -Changes $changes -WhatIf -Verbose

# 5. Test with small batch
Submit-PSContactChange -Changes $changes -Limit 2
```

## Example Scripts

The repository includes complete example scripts:

- **`Example-ContactChangeDetection.ps1`** - Complete workflow for detecting contact changes
- **`Example-ContactSubmitChanges.ps1`** - Simple wrapper for submitting changes from JSON file

### Using Example-ContactSubmitChanges.ps1

```powershell
# Basic usage
./scripts/Example-ContactSubmitChanges.ps1 -ChangeFilePath './data/pending/2026-02-18-contact-changes.json'

# With limit for testing
./scripts/Example-ContactSubmitChanges.ps1 `
    -ChangeFilePath './data/pending/2026-02-18-contact-changes.json' `
    -Limit 5

# Batch processing
./scripts/Example-ContactSubmitChanges.ps1 `
    -ChangeFilePath './data/pending/2026-02-18-contact-changes.json' `
    -Skip 0 -Limit 25

./scripts/Example-ContactSubmitChanges.ps1 `
    -ChangeFilePath './data/pending/2026-02-18-contact-changes.json' `
    -Skip 25 -Limit 25
```

## Best Practices

### 1. Always Use WhatIf First

```powershell
# Preview before applying
Submit-PSContactChange -JsonPath $changeFile -WhatIf -Verbose
```

### 2. Start with Small Test Batches

```powershell
# Test with 1-2 contacts first
Submit-PSContactChange -JsonPath $changeFile -Limit 2

# Then gradually increase
Submit-PSContactChange -JsonPath $changeFile -Limit 10
```

### 3. Export Changes for Review

```powershell
# Always export for manual review before applying
$changes | ConvertTo-Json -Depth 10 | Out-File './pending-changes.json'
```

### 4. Monitor Results

```powershell
$result = Submit-PSContactChange -JsonPath $changeFile

# Always check for failures
if ($result.FailedChanges.Count -gt 0) {
    Write-Warning "Review failed changes:"
    $result.FailedChanges | Export-Csv './failed-changes.csv' -NoTypeInformation
}
```

### 5. Use Batch Processing for Large Updates

```powershell
# Process large files in controlled batches
$batchSize = 25
for ($skip = 0; $skip -lt $totalChanges; $skip += $batchSize) {
    Submit-PSContactChange -JsonPath $changeFile -Skip $skip -Limit $batchSize
    Start-Sleep -Seconds 2  # Pause between batches
}
```

## See Also

- [Compare-PSContact Examples](../user/PowerSchool-ChangeDetection-Usage.md#contact-change-detection) - Detecting contact changes
- [PowerQuery Association IDs Update](../../updates/PowerQuery-Association-IDs-Update.md) - Required plugin update for email/phone/address operations
- [Submit-PSStudentChange Usage](Submit-PSStudentChange-Usage.md) - Similar workflow for student changes
- [PowerSchool Change Detection Guide](../user/PowerSchool-ChangeDetection-Usage.md) - Complete change detection guide
