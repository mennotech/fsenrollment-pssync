# PowerSchool Student API - Implementation Guide

This document describes the actual implementation of the PowerSchool Student API integration based on the working code in `Submit-PSStudentChange`.

## API Endpoint

**URL**: `POST /ws/v1/student`

**Note**: PowerSchool uses the same `POST` endpoint for both creating new students (INSERT) and updating existing students (UPDATE). The operation is determined by the `action` field in the payload.

## Authentication

All requests require Bearer token authentication:

```
Authorization: Bearer {access_token}
Content-Type: application/json
Accept: application/json
```

Use `Connect-PowerSchool` to obtain an access token before making API calls.

## Request Payload Structure

### Common Fields

All requests must include:

```json
{
  "students": {
    "student": {
      "client_uid": "string",  // Required - see below for INSERT vs UPDATE
      "action": "INSERT|UPDATE"  // Required - operation type
      // ... additional fields
    }
  }
}
```

### Creating a New Student (INSERT)

**Required Fields**:
- `client_uid`: Set to the student number (same as `local_id`)
- `action`: Set to `"INSERT"`
- `local_id`: Student number

**Example**:

```json
{
  "students": {
    "student": {
      "client_uid": "123456",
      "action": "INSERT",
      "local_id": "123456",
      "school_id": "100",
      "grade_level": 9,
      "name": {
        "first_name": "John",
        "middle_name": "Q",
        "last_name": "Doe"
      },
      "gender": "M",
      "dob": "2005-06-15",
      "enroll_status": 0,
      "street": "123 Main St",
      "city": "Springfield",
      "state": "IL",
      "zip": "62701",
      "home_phone": "555-1234"
    }
  }
}
```

### Updating an Existing Student (UPDATE)

**Required Fields**:
- `client_uid`: Set to the student DCID as a string
- `action`: Set to `"UPDATE"`
- `id`: Student DCID (PowerSchool internal ID)

**Note**: Only include fields that are being changed.

**Example**:

```json
{
  "students": {
    "student": {
      "client_uid": "12345",
      "action": "UPDATE",
      "id": 12345,
      "name": {
        "first_name": "Jonathan"
      },
      "grade_level": 10
    }
  }
}
```

## Field Mapping

### Core Demographic Fields

| PSStudent Property | PowerSchool API Field | Type | Notes |
|-------------------|----------------------|------|-------|
| StudentNumber | local_id | string | Student number |
| SchoolID | school_id | string | School identifier |
| GradeLevel | grade_level | integer | Grade level (K=0, 1=1, etc.) |
| Gender | gender | string | M/F |
| EnrollStatus | enroll_status | integer | 0=Active, etc. |

### Name Fields (Nested Object)

Name fields are nested under a `name` object:

| PSStudent Property | PowerSchool API Field | Type |
|-------------------|----------------------|------|
| FirstName | name.first_name | string |
| MiddleName | name.middle_name | string |
| LastName | name.last_name | string |

### Date Fields

Dates must be formatted as `YYYY-MM-DD`:

| PSStudent Property | PowerSchool API Field | Format |
|-------------------|----------------------|--------|
| DOB | dob | YYYY-MM-DD |
| EntryDate | entrydate | YYYY-MM-DD |
| ExitDate | exitdate | YYYY-MM-DD |

**Implementation Note**: The code checks if the value is a `DateTime` object and formats it using `ToString('yyyy-MM-dd')`.

### Address Fields

| PSStudent Property | PowerSchool API Field | Type |
|-------------------|----------------------|------|
| Street | street | string |
| City | city | string |
| State | state | string |
| Zip | zip | string |
| MailingStreet | mailing_street | string |
| MailingCity | mailing_city | string |
| MailingState | mailing_state | string |
| MailingZip | mailing_zip | string |

### Contact Fields

| PSStudent Property | PowerSchool API Field | Type |
|-------------------|----------------------|------|
| HomePhone | home_phone | string |
| FamilyIdent | family_ident | string |

### Other Fields

| PSStudent Property | PowerSchool API Field | Type | Notes |
|-------------------|----------------------|------|-------|
| TransferComment | transfer_comment | string | Transfer comments |

## API Response

### Success Response (200 OK)

```json
{
  "result": {
    "status": "SUCCESS",
    "client_uid": "123456",
    "action_performed": "INSERT",
    "student_dcid": 12345
  }
}
```

### Error Responses

| Status Code | Description |
|-------------|-------------|
| 400 | Bad Request - Invalid data format |
| 401 | Unauthorized - Invalid or expired access token |
| 422 | Unprocessable Entity - Data validation failed |
| 429 | Too Many Requests - Rate limit exceeded |
| 500+ | Server Error - PowerSchool internal error |

## Error Handling and Retry Logic

The implementation includes automatic retry logic with exponential backoff:

- **Default Retries**: 3 attempts
- **Initial Delay**: 5 seconds
- **Backoff Strategy**: Exponential (doubles each retry)
- **Retry Conditions**:
  - HTTP 429 (Rate Limiting) - respects Retry-After header
  - HTTP 5xx (Server Errors)
  - Network timeouts and connection errors

### Configuration

```powershell
Submit-PSStudentChange -Changes $changes `
    -MaxRetries 5 `
    -RetryDelaySeconds 10
```

## Usage Examples

### Complete Workflow

```powershell
# 1. Connect to PowerSchool
Connect-PowerSchool

# 2. Detect changes
$csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
$psStudents = Get-PowerSchoolStudent -All
$changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents

# 3. Preview changes (no connection required for WhatIf)
Submit-PSStudentChange -Changes $changes -WhatIf

# 4. Apply changes
$result = Submit-PSStudentChange -Changes $changes
```

### WhatIf Mode

WhatIf mode shows the exact API calls that would be made without requiring a PowerSchool connection:

```powershell
Submit-PSStudentChange -Changes $changes -WhatIf
```

**Output Example**:
```
WhatIf: Would apply 5 of 5 changes

=== WHATIF: New Student Creation ===
Student: 123456 (John Doe)
API Endpoint: POST https://your-school.powerschool.com/ws/v1/student
API Payload:
{
  "students": {
    "student": {
      "client_uid": "123456",
      "action": "INSERT",
      "local_id": "123456",
      "name": {
        "first_name": "John",
        "last_name": "Doe"
      },
      "grade_level": 9
    }
  }
}
```

### Limited Testing

Test with a small batch before applying all changes:

```powershell
# Test with first 5 changes
Submit-PSStudentChange -Changes $changes -Limit 5

# If successful, apply the rest
Submit-PSStudentChange -Changes $changes
```

## Implementation Details

### Function: `Build-StudentPayload`

Converts a `PSStudent` object to PowerSchool API payload format for INSERT operations.

**Key Behaviors**:
- Adds `client_uid` set to StudentNumber
- Sets `action` to "INSERT"
- Formats dates as YYYY-MM-DD
- Creates nested `name` object for name fields
- Only includes non-null/non-empty fields

### Function: `Build-UpdatePayload`

Converts change records to PowerSchool API payload format for UPDATE operations.

**Key Behaviors**:
- Adds `client_uid` set to DCID (as string)
- Sets `action` to "UPDATE"
- Includes `id` field with DCID
- Only includes changed fields
- Formats dates as YYYY-MM-DD if they are DateTime objects
- Handles PowerSchoolAPIField mappings from change detection

### Function: `Invoke-CreateStudent`

Makes the actual API call for student creation.

**Key Behaviors**:
- Validates PowerSchool connection
- Gets current access token
- Uses `Invoke-PowerSchoolApiRequest` with retry logic
- Returns success/error status

### Function: `Invoke-UpdateStudent`

Makes the actual API call for student updates.

**Key Behaviors**:
- Validates PowerSchool connection
- Gets current access token
- Uses POST to `/ws/v1/student` (same endpoint as INSERT)
- Includes DCID in payload with action="UPDATE"
- Uses `Invoke-PowerSchoolApiRequest` with retry logic
- Returns success/error status

## Extension Fields

**Note**: Extension fields (custom PowerSchool fields) are not fully implemented yet. The code will warn about extension field updates:

```
Warning: Extension field updates not yet implemented: extension.table_name.field_name
```

For extension fields, you would need to structure them according to PowerSchool's extension data format.

## Best Practices

1. **Always use WhatIf first** to preview API calls
2. **Start with small batches** using `-Limit` parameter
3. **Monitor rate limits** - PowerSchool may throttle requests
4. **Check results object** for failed changes
5. **Use appropriate retry settings** for your network conditions
6. **Test in non-production environment** first
7. **Backup data** before bulk operations

## Troubleshooting

### Connection Errors

```powershell
# Verify connection
Test-PowerSchoolConnection

# Reconnect if needed
Connect-PowerSchool -Force
```

### Rate Limiting

If you encounter HTTP 429 errors frequently:

```powershell
# Increase retry delay
Submit-PSStudentChange -Changes $changes -RetryDelaySeconds 10

# Process in smaller batches
Submit-PSStudentChange -Changes $changes -Limit 10
```

### Validation Errors (HTTP 422)

Check the error details in the result object:

```powershell
$result = Submit-PSStudentChange -Changes $changes

if ($result.FailedChanges.Count -gt 0) {
    $result.FailedChanges | ForEach-Object {
        Write-Host "Failed: $($_.MatchKey)"
        Write-Host "Error: $($_.Error)"
    }
}
```

## References

- PowerSchool API Documentation: Contact your PowerSchool administrator
- Module Documentation: See `docs/Submit-PSStudentChange-Usage.md`
- Test Examples: See `fsenrollment-pssync/tests/Submit-PSStudentChange.Tests.ps1`
