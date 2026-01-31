# Submit-PSStudentChange Usage Examples

This document demonstrates how to use the `Submit-PSStudentChange` function to apply student changes detected by `Compare-PSStudent` to PowerSchool.

## Prerequisites

1. PowerSchool API credentials configured
2. Active PowerSchool connection (`Connect-PowerSchool`)
3. Changes detected using `Compare-PSStudent` (either in memory or exported to JSON)

## Basic Workflow

### 1. Complete Workflow: Detect and Apply Changes

```powershell
# Import the module
Import-Module FSEnrollment-PSSync

# Connect to PowerSchool
Connect-PowerSchool

# Import CSV data
$csvData = Import-FSCsv -Path './data/students.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_students'

# Get PowerSchool data (automatically detects required extensions and expansions)
$psStudents = Get-PowerSchoolStudent -All -TemplateMetadata $csvData.TemplateMetadata

# Compare to detect changes
$changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents

# Review changes
Write-Host "Found $($changes.Summary.NewCount) new and $($changes.Summary.UpdatedCount) updated students"

# Apply changes to PowerSchool
$result = Submit-PSStudentChange -Changes $changes

# Review results
Write-Host "Successfully applied $($result.Summary.TotalApplied) changes"
if ($result.FailedChanges.Count -gt 0) {
    Write-Warning "Failed to apply $($result.FailedChanges.Count) changes"
    $result.FailedChanges | Format-Table MatchKey, Type, Error
}
```

### 2. Review and Approve Workflow (Recommended)

```powershell
# Step 1: Detect changes and export to JSON for review
$changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents
$changes | ConvertTo-Json -Depth 10 | Out-File './data/pending_changes.json'

Write-Host "Changes exported to pending_changes.json for review"

# Step 2: Manually review the JSON file
# Open and review ./data/pending_changes.json

# Step 3: Apply changes after approval
$result = Submit-PSStudentChange -JsonPath './data/pending_changes.json'
```

### 3. Testing with Live Data (Limited Changes)

When first testing with live PowerSchool data, use the `-Limit` parameter to apply only a few changes:

```powershell
# Test with just 5 changes using WhatIf first
Submit-PSStudentChange -JsonPath './data/pending_changes.json' -Limit 5 -WhatIf

# If WhatIf looks good, apply the test batch
$testResult = Submit-PSStudentChange -JsonPath './data/pending_changes.json' -Limit 5

# Review the results carefully
Write-Host "Test Results:"
Write-Host "  Applied: $($testResult.Summary.TotalApplied)"
Write-Host "  Failed: $($testResult.Summary.TotalFailed)"

# IMPORTANT: After testing with -Limit, you need to manually track which changes
# were applied to avoid reprocessing. The function processes changes in order
# (New students first, then Updates). Consider one of these approaches:

# Option 1: Test with WhatIf, then apply all at once
Submit-PSStudentChange -JsonPath './data/pending_changes.json' -Limit 5 -WhatIf
# Review output, then apply all changes
Submit-PSStudentChange -JsonPath './data/pending_changes.json'

# Option 2: Export separate test and production change files
# Process and review a subset, then process remaining separately

# Option 3: Use the result to track progress and filter remaining changes
# (This requires manual processing of the changes object)
```

### 4. Dry Run (Preview Changes Without Applying)

Use `-WhatIf` to preview what would be changed without actually making changes:

```powershell
# Preview changes without applying them
Submit-PSStudentChange -JsonPath './data/pending_changes.json' -WhatIf

# Output will show what would be changed
# Example: "What if: Performing the operation "Create in PowerSchool" on target "New Student: 123456 (John Doe)"."
```

## Advanced Usage

### Custom Retry Settings

For unreliable network connections or heavily loaded PowerSchool servers:

```powershell
# Apply with increased retry attempts and longer delays
$result = Submit-PSStudentChange -Changes $changes `
    -MaxRetries 5 `
    -RetryDelaySeconds 10
```

### Processing Only New Students

```powershell
# Filter changes to only new students
$newStudentsOnly = [PSCustomObject]@{
    New = $changes.New
    Updated = @()
    Summary = $changes.Summary
}

$result = Submit-PSStudentChange -Changes $newStudentsOnly
Write-Host "Created $($result.NewStudentsApplied) new students"
```

### Processing Only Updates

```powershell
# Filter changes to only updates
$updatesOnly = [PSCustomObject]@{
    New = @()
    Updated = $changes.Updated
    Summary = $changes.Summary
}

$result = Submit-PSStudentChange -Changes $updatesOnly
Write-Host "Updated $($result.UpdatedStudentsApplied) students"
```

### Batch Processing with Checkpoints

For large datasets, process in batches with checkpoints:

```powershell
# Load changes
$allChanges = Get-Content './data/pending_changes.json' | ConvertFrom-Json

$batchSize = 50
$totalNew = $allChanges.New.Count
$totalUpdated = $allChanges.Updated.Count
$processed = 0

# Process in batches
while ($processed -lt ($totalNew + $totalUpdated)) {
    Write-Host "Processing batch starting at $processed..."
    
    $result = Submit-PSStudentChange -Changes $allChanges -Limit $batchSize
    $processed += $result.Summary.TotalApplied
    
    # Save checkpoint
    $checkpoint = [PSCustomObject]@{
        Timestamp = Get-Date
        Processed = $processed
        TotalApplied = $result.Summary.TotalApplied
        TotalFailed = $result.Summary.TotalFailed
    }
    $checkpoint | ConvertTo-Json | Out-File "./data/checkpoint_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    
    # Pause between batches
    Start-Sleep -Seconds 5
}
```

## Error Handling

### Review Failed Changes

```powershell
$result = Submit-PSStudentChange -JsonPath './data/pending_changes.json'

if ($result.FailedChanges.Count -gt 0) {
    Write-Warning "Some changes failed to apply"
    
    # Export failed changes for investigation
    $result.FailedChanges | ConvertTo-Json -Depth 10 | 
        Out-File './data/failed_changes.json'
    
    # Display details
    foreach ($failed in $result.FailedChanges) {
        Write-Host "Failed: $($failed.Type) - $($failed.MatchKey)" -ForegroundColor Red
        Write-Host "  Error: $($failed.Error)" -ForegroundColor Red
    }
}
```

### Retry Failed Changes

```powershell
# Load failed changes
$failed = Get-Content './data/failed_changes.json' | ConvertFrom-Json

# Reconstruct changes object with only failed items
$retryChanges = [PSCustomObject]@{
    New = $failed | Where-Object { $_.Type -eq 'New' }
    Updated = $failed | Where-Object { $_.Type -eq 'Update' }
}

# Retry with more aggressive retry settings
$retryResult = Submit-PSStudentChange -Changes $retryChanges `
    -MaxRetries 5 `
    -RetryDelaySeconds 10
```

## Best Practices

1. **Always Review Changes First**: Export changes to JSON and review before applying
2. **Start Small**: Use `-Limit` for initial testing with live data
3. **Use WhatIf**: Preview changes with `-WhatIf` before committing
4. **Monitor Results**: Always check the result object for failed changes
5. **Batch Processing**: For large datasets, process in batches to avoid timeouts
6. **Save Checkpoints**: When processing large batches, save progress checkpoints
7. **Backup First**: Consider backing up PowerSchool data before applying large changes
8. **Test Connection**: Verify PowerSchool connection before applying changes

## Output Interpretation

The function returns a PSCustomObject with the following structure:

```powershell
@{
    NewStudentsApplied = 5        # Number of new students successfully created
    UpdatedStudentsApplied = 12   # Number of students successfully updated
    FailedChanges = @(            # List of changes that failed
        @{
            Type = 'New'          # or 'Update'
            MatchKey = '123456'   # Student identifier
            Student = ...         # Student data (for new students)
            Changes = ...         # Change details (for updates)
            Error = 'Error message'
        }
    )
    Summary = @{
        TotalProcessed = 17       # Total changes processed
        TotalApplied = 17         # Successfully applied
        TotalFailed = 0           # Failed to apply
        LimitApplied = $false     # Whether limit was reached
    }
}
```

## Limitations

- **Contact Information**: This function only applies student demographic changes. Contact information changes require a separate function.
- **Extension Fields**: Some PowerSchool extension fields may not be supported yet.
- **Validation**: The function does not perform comprehensive data validation beyond what PowerSchool API enforces.

## Troubleshooting

### Connection Issues

```powershell
# Verify connection before applying
Test-PowerSchoolConnection

# If connection expired, reconnect
Connect-PowerSchool -Force
```

### API Rate Limiting

If you encounter rate limiting (HTTP 429 errors), the function will automatically retry with exponential backoff. You can also:

```powershell
# Reduce batch size
Submit-PSStudentChange -Changes $changes -Limit 10

# Increase retry settings
Submit-PSStudentChange -Changes $changes -MaxRetries 5 -RetryDelaySeconds 10
```

### Viewing Detailed Progress

```powershell
# Enable verbose output for detailed progress
Submit-PSStudentChange -JsonPath './data/pending_changes.json' -Verbose
```
