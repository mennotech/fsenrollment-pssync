# PowerQuery: com.fsenrollment.dats.person.email

## Overview

The `com.fsenrollment.dats.person.email` PowerQuery returns email address records for persons from the PowerSchool person table. This query retrieves email addresses with their associated metadata including type, priority order, and primary status.

## Usage

```powershell
# Basic execution (returns first 100 records)
$emailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email'

# Get all email records using pagination
$allEmailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords

# With verbose output to monitor progress
$emailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -Verbose
```

## Data Structure

The query returns records with the following structure:

### Response Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `QueryName` | string | The name of the executed PowerQuery |
| `RecordCount` | integer | Number of email records returned |
| `Records` | array | Array of email record objects |
| `PaginationUsed` | boolean | Whether pagination was used (false for standard call) |
| `TotalRecords` | integer | Total available records (only when using `-AllRecords`) |

### Email Record Fields

Each record in the `Records` array contains the following fields:

#### Person Identifiers
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_id` | integer | Primary person ID | `12345` |
| `person_dcid` | integer | Person DCID (Data Collection ID) | `12400` |

#### Email Information
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `emailaddress_id` | integer | Unique email address ID | `98765` |
| `emailaddress_emailaddress` | string | The email address | `"john.doe@example.com"` |
| `emailaddress_type` | string | Type of email address | `"Home"`, `"Work"`, `"Other"` |
| `emailaddress_order` | integer | Priority order (1 = highest priority) | `1` |
| `emailaddress_isprimary` | integer | Whether this is the primary email (1=yes, 0=no) | `1` |

#### Metadata Fields
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `emailaddress_whencreated` | datetime | When the email record was created | `"2025-04-25 10:17:37.24"` |
| `emailaddress_whenmodified` | datetime | When the email record was last modified | `"2025-04-25 14:17:37.0"` |

## Sample Response

```json
{
  "QueryName": "com.fsenrollment.dats.person.email",
  "RecordCount": 100,
  "Records": [
    {
      "person_id": 12345,
      "person_dcid": 12400,
      "emailaddress_id": 98765,
      "emailaddress_emailaddress": "john.doe@example.com",
      "emailaddress_type": "Home",
      "emailaddress_order": 1,
      "emailaddress_isprimary": 1,
      "emailaddress_whencreated": "2025-04-25 10:17:37.24",
      "emailaddress_whenmodified": "2025-04-25 14:17:37.0"
    },
    {
      "person_id": 12345,
      "person_dcid": 12400,
      "emailaddress_id": 98766,
      "emailaddress_emailaddress": "jdoe@work.com",
      "emailaddress_type": "Work",
      "emailaddress_order": 2,
      "emailaddress_isprimary": 0,
      "emailaddress_whencreated": "2025-05-10 12:30:15.0",
      "emailaddress_whenmodified": "2025-05-10 12:30:15.0"
    }
  ],
  "PaginationUsed": false
}
```

## Field Details and Notes

### Required vs Optional Fields

**Always Present:**
- `person_id`
- `person_dcid`
- `emailaddress_id`
- `emailaddress_emailaddress`
- `emailaddress_whencreated`
- `emailaddress_whenmodified`

**Commonly Present:**
- `emailaddress_type` (should always be present)
- `emailaddress_order` (defaults to system-assigned value)
- `emailaddress_isprimary` (0 or 1)

### Data Type Details

#### Boolean Fields (stored as integers)
- **Format**: `0` (false) or `1` (true)
- **Example**: `emailaddress_isprimary: 1`
- **Note**: PowerSchool stores boolean values as integers

#### Priority Order
- **Format**: Integer starting at 1
- **Purpose**: Determines display order and preference
- **Note**: Lower numbers indicate higher priority

#### Email Type Codes
- **Common Values**: `"Home"`, `"Work"`, `"Other"`
- **Note**: Actual values depend on PowerSchool codeset configuration

## Common Use Cases

### Get Primary Email for Each Person
```powershell
$emails = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
$primaryEmails = $emails.Records | Where-Object { $_.emailaddress_isprimary -eq 1 }
```

### Group Emails by Person
```powershell
$emails = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
$emailsByPerson = $emails.Records | Group-Object -Property person_id
```

### Find Recently Updated Emails
```powershell
$emails = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
$recentDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
$recentlyModified = $emails.Records | Where-Object { 
    $_.emailaddress_whenmodified -gt $recentDate 
}
```

### Export for Analysis
```powershell
$allEmails = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
$allEmails.Records | Export-Csv -Path "email_addresses_export.csv" -NoTypeInformation
```

## Performance Considerations

- **Default Page Size**: 100 records per request
- **Typical Dataset**: Multiple records per person (varies by contact data completeness)
- **Pagination**: Use `-AllRecords` for complete datasets
- **Memory Usage**: Each record ~400-600 bytes

## Related Queries

This query is typically used in conjunction with:
- `com.fsenrollment.dats.person` to get basic person information
- `com.fsenrollment.dats.person.phone` to get phone numbers
- `com.fsenrollment.dats.person.address` to get addresses

## PowerSchool Plugin Requirements

This query requires the FSEnrollment PowerSchool plugin with appropriate permissions for:
- Person table read access
- Email address table read access
- Person email address association table read access
- Codeset table read access (for email type codes)

See the plugin configuration files for detailed permission mappings.

## Change Detection

This query is used by the `Compare-PSContact` function to detect changes in email addresses between CSV imports and PowerSchool data. Changes detected include:
- New email addresses
- Modified email addresses
- Changes to email type
- Changes to priority order
- Changes to primary status
