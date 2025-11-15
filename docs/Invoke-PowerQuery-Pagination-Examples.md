# Invoke-PowerQuery Pagination Examples

This document provides examples of using the new `-AllRecords` parameter in the `Invoke-PowerQuery` function to retrieve all records using pagination.

## Overview

PowerSchool PowerQueries return a maximum of 100 records per request by default. When you need to retrieve all records from queries that return more than 100 results, you can use the `-AllRecords` switch parameter to automatically handle pagination.

## How It Works

When you use `-AllRecords`:
1. The function first calls the PowerSchool `/count` endpoint to get the total number of records
2. It calculates how many pages of 100 records each are needed
3. It makes multiple API calls to retrieve all pages
4. It combines all results into a single response object

## Basic Usage

### Retrieve All Records
```powershell
# Get all student records using pagination
$allStudents = Invoke-PowerQuery -PowerQueryName "com.abc.dats.students.contacts.email" -AllRecords

Write-Output "Retrieved $($allStudents.RecordCount) total records"
Write-Output "Pagination was used: $($allStudents.PaginationUsed)"
Write-Output "Total records available: $($allStudents.TotalRecords)"
```

### Compare Standard vs All Records
```powershell
# Standard call (first 100 records only)
$firstPage = Invoke-PowerQuery -PowerQueryName "com.abc.dats.students.contacts.email"
Write-Output "First page: $($firstPage.RecordCount) records"
Write-Output "Pagination used: $($firstPage.PaginationUsed)"

# All records using pagination
$allRecords = Invoke-PowerQuery -PowerQueryName "com.abc.dats.students.contacts.email" -AllRecords
Write-Output "All records: $($allRecords.RecordCount) records"
Write-Output "Pagination used: $($allRecords.PaginationUsed)"
Write-Output "Total available: $($allRecords.TotalRecords)"
```

### With Arguments
```powershell
# Get all Grade 12 students using pagination
$grade12Students = Invoke-PowerQuery `
    -PowerQueryName "com.abc.dats.students.bygrade" `
    -Arguments @{ gradeLevel = "12" } `
    -AllRecords

Write-Output "Found $($grade12Students.RecordCount) Grade 12 students across $([Math]::Ceiling($grade12Students.TotalRecords / 100)) pages"
```

## Response Object Properties

When using `-AllRecords`, the response object includes additional properties:

```powershell
$result = Invoke-PowerQuery -PowerQueryName "com.example.query" -AllRecords

# Standard properties
$result.QueryName       # The name of the PowerQuery executed
$result.RecordCount     # Number of records actually retrieved
$result.Records         # Array of all retrieved records

# Pagination-specific properties
$result.TotalRecords    # Total number of records available (from /count endpoint)
$result.PaginationUsed  # Boolean indicating pagination was used ($true)
```

For standard (non-paginated) calls:
```powershell
$result = Invoke-PowerQuery -PowerQueryName "com.example.query"

$result.QueryName       # The name of the PowerQuery executed
$result.RecordCount     # Number of records in first page (max 100)
$result.Records         # Array of records from first page
$result.PaginationUsed  # Boolean indicating pagination was NOT used ($false)
# Note: TotalRecords property is not included for non-paginated calls
```

## Performance Considerations

- **Large datasets**: Use `-AllRecords` when you need complete data sets
- **API rate limits**: The function includes retry logic, but be aware that retrieving thousands of records will make many API calls
- **Memory usage**: Large result sets will consume more memory
- **Time**: Retrieving all records takes longer than getting just the first page

Example with verbose output to monitor progress:
```powershell
$allRecords = Invoke-PowerQuery `
    -PowerQueryName "com.large.dataset.query" `
    -AllRecords `
    -Verbose

# You'll see verbose output like:
# VERBOSE: Total records available: 2500
# VERBOSE: Will retrieve 25 pages of 100 records each
# VERBOSE: Retrieving page 1 of 25
# VERBOSE: Added 100 records from page 1
# VERBOSE: Retrieving page 2 of 25
# ...
```

## Error Handling

The function includes comprehensive error handling for pagination scenarios:

```powershell
try {
    $allRecords = Invoke-PowerQuery -PowerQueryName "com.example.query" -AllRecords
    
    if ($allRecords.RecordCount -eq 0) {
        Write-Warning "No records found"
    } else {
        Write-Output "Successfully retrieved $($allRecords.RecordCount) records"
    }
}
catch {
    Write-Error "Failed to retrieve records: $($_.Exception.Message)"
}
```

## When to Use -AllRecords

✅ **Use -AllRecords when:**
- You need complete datasets for analysis
- Generating comprehensive reports
- Data synchronization scenarios
- You know the dataset is large (>100 records)

❌ **Don't use -AllRecords when:**
- You only need a sample of data
- Working with very large datasets where you can filter first
- Building interactive applications where pagination is preferred
- You're just testing or debugging

## Best Practices

1. **Filter first**: Use PowerQuery arguments to reduce the total number of records before using `-AllRecords`
2. **Monitor performance**: Use `-Verbose` to track progress on large datasets
3. **Handle errors**: Always wrap in try-catch blocks for production code
4. **Consider memory**: Be aware of memory usage with very large result sets
5. **Use sparingly**: Reserve for cases where you truly need all records

Example of filtering first:
```powershell
# Good: Filter to specific school and date range first
$recentStudents = Invoke-PowerQuery `
    -PowerQueryName "com.abc.dats.students.detailed" `
    -Arguments @{ 
        schoolId = "123"
        startDate = "2024-01-01"
        endDate = "2024-12-31"
    } `
    -AllRecords

# Less optimal: Getting all students from all schools and all time
$allStudentsEver = Invoke-PowerQuery `
    -PowerQueryName "com.abc.dats.students.detailed" `
    -AllRecords  # Could be millions of records!
```