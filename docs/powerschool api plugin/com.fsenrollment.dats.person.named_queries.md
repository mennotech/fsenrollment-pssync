# PowerQuery: com.fsenrollment.dats.person

## Overview

The `com.fsenrollment.dats.person` PowerQuery returns person records from the PowerSchool person table. This query retrieves basic person information including names, identifiers, and metadata fields.

## Usage

```powershell
# Basic execution (returns first 100 records)
$personData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person'

# Get all person records using pagination
$allPersonData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords

# With verbose output to monitor progress
$personData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -Verbose
```

## Data Structure

The query returns records with the following structure:

### Response Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `QueryName` | string | The name of the executed PowerQuery |
| `RecordCount` | integer | Number of person records returned |
| `Records` | array | Array of person record objects |
| `PaginationUsed` | boolean | Whether pagination was used (false for standard call) |
| `TotalRecords` | integer | Total available records (only when using `-AllRecords`) |

### Person Record Fields

Each record in the `Records` array contains the following fields:

#### Core Identifiers
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_id` | integer | Primary person ID | `12345` |
| `person_dcid` | integer | Person DCID (Data Collection ID) | `12400` |
| `_id` | integer | Internal record identifier | `12345` |
| `_name` | string | Table name (always "Person") | `"Person"` |

#### Personal Information
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_firstname` | string | Person's first name | `"John"` |
| `person_lastname` | string | Person's last name | `"Doe"` |
| `person_middlename` | string | Person's middle name (optional) | `"William"` |
| `person_gender_code` | string | Gender code (M/F) | `"M"` |

#### State Integration
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_statecontactid` | string | State contact identifier (optional) | `"12345678-abcd-1234-efgh-123456789012"` |

#### Employment Information
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_employer` | string | Person's employer (optional) | `"Example Corp"` |

#### Metadata Fields
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_whencreated` | datetime | When the record was created | `"2025-04-25 10:17:37.24"` |
| `person_whenmodified` | datetime | When the record was last modified | `"2025-04-25 14:17:37.0"` |

## Sample Response

```json
{
  "QueryName": "com.fsenrollment.dats.person",
  "RecordCount": 100,
  "Records": [
    {
      "person_id": 12345,
      "person_dcid": 12400,
      "_id": 12345,
      "_name": "Person",
      "person_firstname": "John",
      "person_lastname": "Doe",
      "person_gender_code": "M",
      "person_whencreated": "2025-04-25 10:17:37.24",
      "person_whenmodified": "2025-04-25 14:17:37.0"
    },
    {
      "person_id": 12346,
      "person_dcid": 12401,
      "_id": 12346,
      "_name": "Person",
      "person_firstname": "Jane",
      "person_lastname": "Smith",
      "person_gender_code": "F",
      "person_employer": "Example Corp",
      "person_statecontactid": "12345678-abcd-1234-efgh-123456789012",
      "person_whencreated": "2025-07-28 12:58:22.158",
      "person_whenmodified": "2025-07-28 17:58:22.0"
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
- `_id`
- `_name`
- `person_firstname`
- `person_lastname`
- `person_whencreated`
- `person_whenmodified`

**Commonly Present:**
- `person_gender_code` (most records)

**Optional Fields:**
- `person_middlename` (only when specified)
- `person_employer` (only when specified)
- `person_statecontactid` (only for state-integrated records)

### Data Type Details

#### DateTime Fields
- **Format**: `YYYY-MM-DD HH:MM:SS.sss`
- **Example**: `"2025-04-25 10:17:37.24"`
- **Note**: Milliseconds may vary in precision

#### Gender Codes
- **Valid Values**: `"M"`, `"F"`
- **Note**: May be null/empty for some records

#### State Contact ID
- **Format**: UUID (GUID)
- **Example**: `"12345678-abcd-1234-efgh-123456789012"`
- **Purpose**: Links person to state systems

### PowerSchool Extensions

The raw response includes PowerSchool schema extensions:
- `personcorefields`
- `integration_person`

These extensions provide additional metadata about the query structure and available fields.

## Common Use Cases

### Basic Person Lookup
```powershell
$persons = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person'
$persons.Records | Where-Object { $_.person_lastname -eq "Smith" }
```

### Finding Recently Modified Records
```powershell
$persons = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
$recentDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
$recentlyModified = $persons.Records | Where-Object { 
    $_.person_whenmodified -gt $recentDate 
}
```

### State Integration Analysis
```powershell
$persons = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
$stateIntegrated = $persons.Records | Where-Object { 
    $_.person_statecontactid -ne $null 
}
Write-Output "State-integrated persons: $($stateIntegrated.Count)"
```

### Export for Analysis
```powershell
$allPersons = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords
$allPersons.Records | Export-Csv -Path "persons_export.csv" -NoTypeInformation
```

## Performance Considerations

- **Default Page Size**: 100 records per request
- **Typical Dataset**: Varies by district size
- **Pagination**: Use `-AllRecords` for complete datasets
- **Memory Usage**: Each record ~300-500 bytes

## Related Queries

This query is typically used in conjunction with:
- Student queries to link person records to student data
- Contact queries to build relationship mappings
- Address queries for complete person profiles

## PowerSchool Plugin Requirements

This query requires the FSEnrollment PowerSchool plugin with appropriate permissions for:
- Person table read access
- Core person fields access
- Integration person fields access (for state contact IDs)

See the plugin configuration files for detailed permission mappings.
