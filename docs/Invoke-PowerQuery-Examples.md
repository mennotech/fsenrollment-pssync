# Invoke-PowerQuery Usage Examples

The `Invoke-PowerQuery` function provides a convenient way to execute PowerSchool PowerQueries with parameters and retrieve results in a structured format.

## Prerequisites

Before using `Invoke-PowerQuery`, you must establish a connection to PowerSchool:

```powershell
# Connect to PowerSchool
Connect-PowerSchool -BaseUrl 'https://your-instance.powerschool.com' -ClientId 'your-client-id' -ClientSecret (Read-Host -AsSecureString -Prompt 'Client Secret')
```

## Basic Usage

### List Available PowerQueries

```powershell
# Get a list of all available PowerQueries
$availableQueries = Invoke-PowerQuery -ListAvailable
$availableQueries | Sort-Object
```

### Execute a PowerQuery without Parameters

```powershell
# Execute a simple PowerQuery
$result = Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.contacts.email"

# Access the results
Write-Host "Records returned: $($result.RecordCount)"
$result.Records | Format-Table
```

### Execute a PowerQuery with Parameters

```powershell
# Execute a PowerQuery with parameters
$arguments = @{
    gradeLevel = "12"
    schoolId = "1"
}

$result = Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.bygrade" -Arguments $arguments

# Display results
$result.Records | Select-Object student_id, first_name, last_name, grade_level | Format-Table
```

### Advanced Usage with Raw Response

```powershell
# Execute with raw JSON response for debugging
$result = Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.contacts.email" -ShowRawResponse

# Access structured data
Write-Host "Query: $($result.QueryName)"
Write-Host "Count: $($result.RecordCount)"

# Access raw JSON for debugging
$result.RawResponse | ConvertTo-Json -Depth 10
```

### Skip Existence Validation

```powershell
# Execute a custom PowerQuery without validating its existence first
# Useful for testing new PowerQueries or when the list endpoint is unavailable
$result = Invoke-PowerQuery -PowerQueryName "com.custom.powerquery" -SkipExistenceCheck
```

## Working with Results

The `Invoke-PowerQuery` function returns a structured object with the following properties:

- **QueryName**: The name of the executed PowerQuery
- **RecordCount**: Number of records returned
- **Records**: Array of result records
- **RawResponse**: Raw JSON response (only when `-ShowRawResponse` is used)

### Filtering and Processing Results

```powershell
# Execute PowerQuery and process results
$students = Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.contacts.email"

# Filter students by grade
$seniorStudents = $students.Records | Where-Object { $_.grade_level -eq "12" }

# Group by school
$studentsBySchool = $students.Records | Group-Object school_abbreviation

# Export to CSV
$students.Records | Export-Csv -Path "students_with_emails.csv" -NoTypeInformation
```

### Pipeline Usage

```powershell
# Use in pipeline for further processing
Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.contacts.email" |
    ForEach-Object { 
        Write-Host "Processing $($_.RecordCount) student records from query: $($_.QueryName)"
        $_.Records | Where-Object { $_.email_addr -like "*@student.district.edu" }
    } |
    Export-Csv -Path "district_student_emails.csv" -NoTypeInformation
```

## Error Handling

```powershell
try {
    $result = Invoke-PowerQuery -PowerQueryName "com.nonexistent.query"
}
catch {
    if ($_.Exception.Message -like "*was not found in the available PowerQueries list*") {
        Write-Warning "PowerQuery does not exist. Use -ListAvailable to see available queries."
        # Optionally retry with -SkipExistenceCheck
        $result = Invoke-PowerQuery -PowerQueryName "com.nonexistent.query" -SkipExistenceCheck
    }
    else {
        Write-Error "PowerQuery execution failed: $($_.Exception.Message)"
    }
}
```

## Performance Considerations

- Use parameters to filter results at the database level rather than filtering large result sets in PowerShell
- For large result sets, consider pagination if supported by the PowerQuery
- Cache results when possible if the data doesn't change frequently

## Integration with Other Module Functions

```powershell
# Combine with other module functions
Connect-PowerSchool -BaseUrl $env:PowerSchool_BaseUrl

# Get students via PowerQuery
$studentsFromQuery = Invoke-PowerQuery -PowerQueryName "com.scs.dats.students.bygrade" -Arguments @{gradeLevel = "12"}

# Get detailed student information using existing function
$studentDetails = foreach ($student in $studentsFromQuery.Records) {
    Get-PowerSchoolStudent -StudentId $student.student_id
}

# Compare with CSV data
$csvData = Import-FSCsv -CsvPath "students.csv"
$comparison = Compare-PSStudent -PowerSchoolData $studentDetails -CsvData $csvData
```

## Best Practices

1. **Always establish connection first**: Use `Connect-PowerSchool` before executing PowerQueries
2. **Validate PowerQuery names**: Use `-ListAvailable` to see available PowerQueries
3. **Use parameters effectively**: Filter data at the database level for better performance
4. **Handle errors gracefully**: Wrap PowerQuery calls in try/catch blocks
5. **Process results efficiently**: Use PowerShell pipeline features for data processing
6. **Cache when appropriate**: Store frequently accessed data in variables
7. **Document custom PowerQueries**: When using `-SkipExistenceCheck`, ensure the PowerQuery exists and is properly documented