# PowerSchool Student API - Implementation Guide

This document describes the actual implementation of the PowerSchool Student API integration based on the working code in `Submit-PSStudentChange` and `Get-PowerSchoolStudent`.

## API Endpoints

### Retrieve Student Data

**URL**: `GET /ws/v1/student/{student_dcid}`

Retrieves a single student record by DCID. Supports expansions to include additional data.

**Query Parameters**:
- `expansions`: Comma-separated list of expansions to include (see Expansion Fields section)
- `extensions`: Comma-separated list of extension tables to include

### Create or Update Student Data

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

### GET Response Structure

When retrieving a student via `GET /ws/v1/student/{student_dcid}`, the response includes:

**Core Fields** (always returned):
- `@expansions`: String listing all expansions included in the response
- `@extensions`: String listing all available extension tables
- `id`: Student DCID (PowerSchool internal ID)
- `local_id`: Student number
- `state_province_id`: State/province identifier
- `name`: Nested object containing name fields

**Expansion Fields** (returned when requested via `expansions` parameter):
- `demographics`: Gender, birth date, projected graduation year
- `addresses`: Physical and mailing addresses
- `school_enrollment`: Current enrollment status, grade level, dates, school assignment
- `initial_enrollment`: District and school entry grade levels
- `contact`: Contact information
- `contact_info`: Additional contact details
- `phones`: Phone numbers
- `alerts`: Student alerts
- `ethnicity_race`: Ethnicity and race information
- `schedule_setup`: Schedule configuration
- `fees`: Fee information
- `lunch`: Lunch program details
- `counselors`: Assigned counselors
- `global_id`: Global identifiers

**Extension Fields** (returned when requested via `extensions` parameter):
- `_extension_data`: Object containing custom extension table data
  - `_table_extension`: Array or object with custom field definitions
  - Each extension table contains `_field` arrays with name, type, and value
  - Extension tables are institution-specific custom fields

### Expansion Field Details

#### Demographics Expansion

Returned when `demographics` is included in expansions parameter:

```json
"demographics": {
  "gender": "M",
  "birth_date": "2020-04-20",
  "projected_graduation_year": 2038
}
```

| Field | Type | Description |
|-------|------|-------------|
| gender | string | Student gender (M/F) |
| birth_date | string | Date of birth (YYYY-MM-DD) |
| projected_graduation_year | integer | Expected graduation year |

#### Addresses Expansion

Returned when `addresses` is included in expansions parameter:

```json
"addresses": {
  "physical": {
    "street": "100 Main Street",
    "city": "Winnipeg",
    "state_province": "MB",
    "postal_code": "R3P 1A2",
    "grid_location": "Lat: 49.8483235, Lng: -97.1823154"
  },
  "mailing": {
    "street": "Box 1234",
    "city": "Winnipeg",
    "state_province": "MB",
    "postal_code": "R3P 3B4",
    "grid_location": "Lat: 49.8483235, Lng: -97.1823154"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| physical.street | string | Physical address street |
| physical.city | string | Physical address city |
| physical.state_province | string | Physical address state/province |
| physical.postal_code | string | Physical address postal code |
| mailing.street | string | Mailing address street |
| mailing.city | string | Mailing address city |
| mailing.state_province | string | Mailing address state/province |
| mailing.postal_code | string | Mailing address postal code |

**Note**: When updating address fields, use the expansion field notation in your change detection:
- `@addresses.physical.street`
- `@addresses.physical.city`
- `@addresses.mailing.postal_code`

#### School Enrollment Expansion

Returned when `school_enrollment` is included in expansions parameter:

```json
"school_enrollment": {
  "enroll_status": "A",
  "enroll_status_description": "Active",
  "enroll_status_code": 0,
  "grade_level": 10,
  "entry_date": "2025-09-02",
  "exit_date": "2026-07-01",
  "school_number": 300,
  "school_id": 5,
  "entry_code": 100,
  "entry_comment": "Promote Same School",
  "full_time_equivalency": {
    "fteid": 101,
    "name": "Full Time"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| enroll_status | string | Status code (A=Active, etc.) |
| enroll_status_description | string | Human-readable status |
| enroll_status_code | integer | Numeric status code |
| grade_level | integer | Current grade (K=0, 1=1, etc.) |
| entry_date | string | School entry date (YYYY-MM-DD) |
| exit_date | string | School exit date (YYYY-MM-DD) |
| school_number | integer | School number |
| school_id | integer | School ID |
| entry_code | integer | Entry code |
| full_time_equivalency | object | FTE information |

#### Initial Enrollment Expansion

Returned when `initial_enrollment` is included in expansions parameter:

```json
"initial_enrollment": {
  "district_entry_grade_level": 0,
  "school_entry_grade_level": 0
}
```

| Field | Type | Description |
|-------|------|-------------|
| district_entry_grade_level | integer | Grade level when entering district |
| school_entry_grade_level | integer | Grade level when entering school |

#### Extension Data

Returned when specific extension tables are requested via `extensions` parameter:

```json
"_extension_data": {
  "_table_extension": {
    "recordFound": true,
    "_field": [
      {
        "name": "pscore_legal_gender",
        "type": "String",
        "value": "M"
      },
      {
        "name": "pscore_legal_first_name",
        "type": "String",
        "value": "Mickennly"
      },
      {
        "name": "allergies",
        "type": "String",
        "value": "Allergy to Nuts"
      },
      {
        "name": "pscore_legal_middle_name",
        "type": "String",
        "value": "Middle Mack"
      },
      {
        "name": "pscore_legal_last_name",
        "type": "String",
        "value": "Mouser"
      }
    ],
    "name": "studentcorefields"
  }
}
```

**Structure**:
- `_extension_data`: Root object for all extension data
- `_table_extension`: Can be a single object or array of extension tables
- `recordFound`: Boolean indicating if extension record exists
- `_field`: Array of field objects, each containing:
  - `name`: Field name
  - `type`: Data type (String, Integer, Date, etc.)
  - `value`: Field value
- `name`: Extension table name

**Note**: Extension tables are institution-specific and contain custom fields defined by your PowerSchool administrator. Common examples include legal names, allergies, additional demographic data, and custom tracking fields.

**Updating Extension Fields**: Extension fields require a special array structure in POST payloads:

```json
{
  "students": {
    "student": {
      "client_uid": "1051",
      "id": 1051,
      "action": "UPDATE",
      "_extension_data": {
        "studentcorefields": {
          "_field": [
            {
              "name": "pscore_legal_first_name",
              "value": "NewValue"
            }
          ]
        }
      }
    }
  }
}
```

**Current Implementation Status**: Extension field updates are **NOT IMPLEMENTED** in the current module. The special array structure (`_field` with `name`/`value` pairs) requires dedicated handling in the `Build-UpdatePayload` function.

### POST (INSERT/UPDATE) Field Mapping

The following mappings apply when creating or updating students via POST operations.

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

**Note**: Address fields use expansion notation when retrieving data but use direct fields when creating/inserting students. When updating existing students, use the expansion field paths.

**For GET operations** (returned via `addresses` expansion):
- `@addresses.physical.street`
- `@addresses.physical.city`
- `@addresses.physical.state_province`
- `@addresses.physical.postal_code`
- `@addresses.mailing.street`
- `@addresses.mailing.city`
- `@addresses.mailing.state_province`
- `@addresses.mailing.postal_code`

**For INSERT operations** (creating new students):

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

**For UPDATE operations** (updating existing students):

Use expansion field notation in change records:
- `@addresses.physical.street`
- `@addresses.physical.city`
- `@addresses.physical.state_province` 
- `@addresses.physical.postal_code`
- `@addresses.mailing.street`
- `@addresses.mailing.city`
- `@addresses.mailing.state_province`
- `@addresses.mailing.postal_code`

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
  "results": {
    "insert_count": 1,
    "update_count": 0,
    "delete_count": 0,
    "result": {
      "client_uid": "123456",
      "status": "SUCCESS",
      "action": "INSERT",
      "success_message": {
        "id": 12345,
        "ref": "https://your-school.powerschool.com/ws/v1/student/12345"
      }
    }
  }
}
```

### Validation Error Response (HTTP 200!)

**Critical**: PowerSchool returns HTTP 200 OK even for validation errors. Check the `status` field in the JSON response:

```json
{
  "results": {
    "insert_count": 0,
    "update_count": 0,
    "delete_count": 0,
    "result": {
      "client_uid": "123456",
      "status": "ERROR",
      "action": "UPDATE",
      "error_message": {
        "error": {
          "field": "students/demographics/birth_date",
          "error_code": "INVALID_DATE_VALUE",
          "error_description": "Date value or date format is invalid."
        }
      }
    }
  }
}
```

**Always check**: `response.results.result.status === "ERROR"` to detect validation failures.

### HTTP Error Responses

| Status Code | Description |
|-------------|-------------|
| 400 | Bad Request - Invalid JSON format |
| 401 | Unauthorized - Invalid or expired access token |
| 422 | Unprocessable Entity - Malformed request |
| 429 | Too Many Requests - Rate limit exceeded |
| 500+ | Server Error - PowerSchool internal error |
## PowerSchool Validation Behavior

Based on live API testing, PowerSchool validates:

**Strict Validation** (will reject with ERROR status):
- Date formats (must be valid date strings like `YYYY-MM-DD`)
- Required fields (e.g., physical address street cannot be empty)

**Permissive Validation** (will accept):
- Empty values for optional fields (e.g., birth_date can be cleared with empty string)
- Out-of-range values (e.g., grade_level = 999 accepted)
- Format variations (e.g., accepts both US ZIP codes and Canadian postal codes)
- Multiple date formats (accepts `MM/DD/YYYY`, converts to `YYYY-MM-DD`)

**Recommendation**: Implement application-level validation for fields like grade level ranges and postal code formats before submitting to API.
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

**Status**: Extension field updates are **IMPLEMENTED** as of January 31, 2026.

**Usage**: Extension fields use the pattern `extension.{table_name}.{field_name}` in change detection.

**Example**:
```powershell
$change = [PSCustomObject]@{
    Field = 'LegalFirstName'
    OldValue = 'John'
    NewValue = 'Jonathan'
    PowerSchoolAPIField = 'extension.studentcorefields.pscore_legal_first_name'
}
```

**Required Structure**: Extension fields must be submitted in the `_table_extension` format:

**GET Response Format** (how extension data is returned):
```json
"_extension_data": {
  "_table_extension": {
    "recordFound": true,
    "_field": [
      {
        "name": "pscore_legal_first_name",
        "type": "String",
        "value": "John"
      }
    ],
    "name": "studentcorefields"
  }
}
```

**POST Request Format** (how extension data must be sent):
```json
{
  "students": {
    "student": {
      "_extension_data": {
        "_table_extension": {
          "name": "studentcorefields",
          "_field": [
            {
              "name": "pscore_legal_first_name",
              "value": "Jonathan"
            }
          ]
        }
      },
      "client_uid": "1234",
      "id": 1234,
      "action": "UPDATE"
    }
  }
}
```

**Critical Requirements**:
1. **Query Parameter**: Must include `?extensions={table_name}` in the URI
2. **Structure**: Use `_extension_data._table_extension` (not `_extension_data.{table_name}`)
3. **Field Format**: Each field requires `name` and `value` properties (minimum)
4. **Table Name**: Specify the table name in the `name` property within `_table_extension`

**Optional Fields**:
- `type`: Not required for updates (PowerSchool returns it in GET responses but doesn't need it in POST)
- `recordFound`: Not required for updates

**Implementation Details**:
- `Merge-ExtensionFieldChanges` function handles building the extension structure
- `Invoke-UpdateStudent` automatically detects extension data and adds `?extensions={table_name}` query parameter
- Uses minimal structure with only `name` and `value` for each field
- Only one extension table can be updated per API call (PowerSchool API limitation)

**PowerSchool API Behavior**:
- Returns HTTP 200 OK with `"status":"SUCCESS"` even if structure is incorrect
- Updates only take effect when all three requirements are met (query parameter, structure, field format)
- No validation error is returned for incorrect structure - the update silently fails


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

## Complete GET Response Example

Example of retrieving a student with multiple expansions and extensions:

```powershell
$student = Get-PowerSchoolStudent -DCID 1051 `
    -Expansions demographics,addresses,school_enrollment,contact,initial_enrollment `
    -Extensions studentcorefields
```

**Response**:

```json
{
  "@expansions": "demographics, addresses, alerts, phones, school_enrollment, ethnicity_race, contact, contact_info, initial_enrollment, schedule_setup, fees, lunch, counselors, global_id",
  "@extensions": "s_mb_stu_x,c_studentlocator,u_mba_report_cards,s_stu_crosslea_x,studentfullnamecorefields,integration_students,s_stu_crdc_x,s_stu_x,activities,u_private_preferred_name,s_stu_directadmit_x,u_students_extension,s_stu_ncea_x,s_stu_edfi_x,studentcorefields",
  "_extension_data": {
    "_table_extension": {
      "recordFound": true,
      "_field": [
        {
          "name": "pscore_legal_gender",
          "type": "String",
          "value": "M"
        },
        {
          "name": "pscore_legal_first_name",
          "type": "String",
          "value": "Mickennly"
        },
        {
          "name": "allergies",
          "type": "String",
          "value": "Allergy to Nuts"
        },
        {
          "name": "pscore_legal_middle_name",
          "type": "String",
          "value": "Middle Mack"
        },
        {
          "name": "pscore_legal_last_name",
          "type": "String",
          "value": "Mouser"
        }
      ],
      "name": "studentcorefields"
    }
  },
  "id": 1051,
  "local_id": 202503,
  "student_username": "mickeymouse",
  "name": {
    "first_name": "Mickey",
    "middle_name": "Middle",
    "last_name": "Mouse"
  },
  "demographics": {
    "gender": "M",
    "birth_date": "2010-01-01",
    "projected_graduation_year": 2028
  },
  "addresses": {
    "physical": {
      "street": "100 Main Street",
      "city": "Winnipeg",
      "state_province": "MB",
      "postal_code": "R3P 1A2",
      "grid_location": "Lat: 49.8483235, Lng: -97.1823154"
    },
    "mailing": {
      "street": "Box 1234",
      "city": "Winnipeg",
      "state_province": "MB",
      "postal_code": "R3P 3B4",
      "grid_location": "Lat: 49.8483235, Lng: -97.1823154"
    }
  },
  "school_enrollment": {
    "enroll_status": "A",
    "enroll_status_description": "Active",
    "enroll_status_code": 0,
    "grade_level": 10,
    "entry_date": "2025-09-02",
    "exit_date": "2026-07-01",
    "school_number": 300,
    "school_id": 5,
    "entry_code": 100,
    "entry_comment": "Promote Same School",
    "full_time_equivalency": {
      "fteid": 101,
      "name": "Full Time"
    }
  },
  "initial_enrollment": {
    "district_entry_grade_level": 0,
    "school_entry_grade_level": 0
  }
}
```

**Key Observations**:
- The `id` field contains the student DCID (1051)
- The `local_id` field contains the student number (202503)
- The `_extension_data` contains custom fields from the `studentcorefields` extension table
- Extension fields include legal names (pscore_legal_first_name, etc.) and custom data (allergies)
- The `@extensions` field lists all available extension tables, but only requested ones are returned in `_extension_data`
- Expansion fields are nested objects, not arrays
- Address data uses `state_province` and `postal_code` (not `state` and `zip`)
- The `@expansions` field shows all expansions included in the response
- Date fields use ISO format: YYYY-MM-DD

## References

- PowerSchool API Documentation: Contact your PowerSchool administrator
- Module Documentation: See `docs/Submit-PSStudentChange-Usage.md`
- Test Examples: See `fsenrollment-pssync/tests/Submit-PSStudentChange.Tests.ps1`
