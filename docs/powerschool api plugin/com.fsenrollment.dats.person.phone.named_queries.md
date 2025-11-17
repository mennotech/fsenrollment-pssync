# PowerQuery: com.fsenrollment.dats.person.phone

## Overview

The `com.fsenrollment.dats.person.phone` PowerQuery returns phone number records for persons from the PowerSchool person table. This query retrieves phone numbers with their associated metadata including type, priority order, SMS capability, and preferred status.

## Usage

```powershell
# Basic execution (returns first 100 records)
$phoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone'

# Get all phone records using pagination
$allPhoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords

# With verbose output to monitor progress
$phoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -Verbose
```

## Data Structure

The query returns records with the following structure:

**Note**: The PowerSchool API omits fields when they are null or empty rather than returning them with null values. Optional fields like `phonenumber_extension` will only be present in the response when they contain data.

### Response Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `QueryName` | string | The name of the executed PowerQuery |
| `RecordCount` | integer | Number of phone records returned |
| `Records` | array | Array of phone record objects |
| `PaginationUsed` | boolean | Whether pagination was used (false for standard call) |
| `TotalRecords` | integer | Total available records (only when using `-AllRecords`) |

### Phone Record Fields

Each record in the `Records` array contains the following fields:

#### Person Identifiers
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_id` | integer | Primary person ID | `12345` |
| `person_dcid` | integer | Person DCID (Data Collection ID) | `12400` |

#### Phone Information
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `phonenumber_id` | integer | Unique phone number ID | `54321` |
| `phonenumber_phonenumber` | string | The formatted phone number | `"(555) 123-4567"` |
| `phonenumber_extension` | string | Phone extension (optional, omitted if null) | `"123"` |
| `phonenumber_type` | string | Type of phone number | `"Home"`, `"Mobile"`, `"Work"` |
| `phonenumber_order` | integer | Priority order (1 = highest priority) | `1` |
| `phonenumber_ispreferred` | integer | Whether this is the preferred phone (1=yes, 0=no) | `1` |
| `phonenumber_issms` | integer | Whether SMS is enabled (1=yes, 0=no) | `1` |

## Sample Response

```json
{
  "QueryName": "com.fsenrollment.dats.person.phone",
  "RecordCount": 100,
  "Records": [
    {
      "phonenumber_phonenumber": "(555) 123-4567",
      "_name": "PhoneNumber",
      "phonenumber_order": 1,
      "phonenumber_ispreferred": 1,
      "phonenumber_issms": 1,
      "_id": 1151,
      "phonenumber_id": 51,
      "person_dcid": 1201,
      "phonenumber_type": "Mobile",
      "person_id": 1151
    },
    {
      "phonenumber_phonenumber": "(555) 987-6543",
      "phonenumber_extension": "123",
      "_name": "PhoneNumber",
      "phonenumber_order": 2,
      "phonenumber_ispreferred": 0,
      "phonenumber_issms": 0,
      "_id": 12345,
      "phonenumber_id": 54322,
      "person_dcid": 12400,
      "phonenumber_type": "Work",
      "person_id": 12345
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
- `phonenumber_id`
- `phonenumber_phonenumber`

**Commonly Present:**
- `phonenumber_type` (should always be present)
- `phonenumber_order` (defaults to system-assigned value)
- `phonenumber_ispreferred` (0 or 1)
- `phonenumber_issms` (0 or 1)

**Optional Fields:**
- `phonenumber_extension` (only when specified)

### Data Type Details

#### Boolean Fields (stored as integers)
- **Format**: `0` (false) or `1` (true)
- **Example**: `phonenumber_issms: 1`, `phonenumber_ispreferred: 1`
- **Note**: PowerSchool stores boolean values as integers

#### Priority Order
- **Format**: Integer starting at 1
- **Purpose**: Determines display order and preference
- **Note**: Lower numbers indicate higher priority

#### Phone Number Format
- **Format**: Varies based on system configuration
- **Common Formats**: `"(555) 123-4567"`, `"555-123-4567"`, `"+1 555 123 4567"`
- **Note**: Format is determined by PowerSchool configuration

#### Phone Type Codes
- **Common Values**: `"Home"`, `"Mobile"`, `"Work"`, `"Other"`
- **Note**: Actual values depend on PowerSchool codeset configuration

## Common Use Cases

### Get Preferred Phone for Each Person
```powershell
$phones = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$preferredPhones = $phones.Records | Where-Object { $_.phonenumber_ispreferred -eq 1 }
```

### Get SMS-Enabled Phones
```powershell
$phones = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$smsPhones = $phones.Records | Where-Object { $_.phonenumber_issms -eq 1 }
```

### Group Phones by Person
```powershell
$phones = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$phonesByPerson = $phones.Records | Group-Object -Property person_id
```

### Get Mobile Numbers Only
```powershell
$phones = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$mobilePhones = $phones.Records | Where-Object { $_.phonenumber_type -eq "Mobile" }
```

### Export for Analysis
```powershell
$allPhones = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$allPhones.Records | Export-Csv -Path "phone_numbers_export.csv" -NoTypeInformation
```

## Performance Considerations

- **Default Page Size**: 100 records per request
- **Typical Dataset**: Multiple records per person (varies by contact data completeness)
- **Pagination**: Use `-AllRecords` for complete datasets
- **Memory Usage**: Each record ~350-550 bytes

## Related Queries

This query is typically used in conjunction with:
- `com.fsenrollment.dats.person` to get basic person information
- `com.fsenrollment.dats.person.email` to get email addresses
- `com.fsenrollment.dats.person.address` to get addresses

## PowerSchool Plugin Requirements

This query requires the FSEnrollment PowerSchool plugin with appropriate permissions for:
- Person table read access
- Phone number table read access
- Person phone number association table read access
- Codeset table read access (for phone type codes)

See the plugin configuration files for detailed permission mappings.

## Change Detection

This query is used by the `Compare-PSContact` function to detect changes in phone numbers between CSV imports and PowerSchool data. Changes detected include:
- New phone numbers
- Modified phone numbers
- Changes to phone type
- Changes to priority order
- Changes to preferred status
- Changes to SMS capability
- Changes to phone extension
