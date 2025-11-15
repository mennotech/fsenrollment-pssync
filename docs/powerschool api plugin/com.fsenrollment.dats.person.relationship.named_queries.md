# PowerQuery: com.fsenrollment.dats.person.relationship

## Overview

The `com.fsenrollment.dats.person.relationship` PowerQuery returns student-contact relationship records for persons from the PowerSchool person table. This query retrieves relationship data including priority order, relationship type, and various relationship flags (custody, emergency contact, lives with, etc.).

## Usage

```powershell
# Basic execution (returns first 100 records)
$relationshipData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship'

# Get all relationship records using pagination
$allRelationshipData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords

# With verbose output to monitor progress
$relationshipData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -Verbose
```

## Data Structure

The query returns records with the following structure:

### Response Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `QueryName` | string | The name of the executed PowerQuery |
| `RecordCount` | integer | Number of relationship records returned |
| `Records` | array | Array of relationship record objects |
| `PaginationUsed` | boolean | Whether pagination was used (false for standard call) |
| `TotalRecords` | integer | Total available records (only when using `-AllRecords`) |

### Relationship Record Fields

Each record in the `Records` array contains the following fields:

#### Person Identifiers
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_id` | integer | Primary person ID | `12345` |
| `person_dcid` | integer | Person DCID (Data Collection ID) | `12400` |

#### Student Identifiers
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `student_student_number` | string | Student number | `"123456"` |
| `student_dcid` | integer | Student DCID | `54321` |

#### Relationship Information
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `relationship_priority_order` | integer | Priority order of this contact for the student | `1` |
| `relationship_relationship_code` | string | Type of relationship (e.g., Mother, Father, Guardian) | `"Mother"` |
| `relationship_relationship_note` | string | Additional notes about the relationship | `"Primary contact"` |

#### Relationship Flags
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `relationship_isactive` | integer | Whether relationship is active (1=yes, 0=no) | `1` |
| `relationship_iscustodial` | integer | Whether contact has custody (1=yes, 0=no) | `1` |
| `relationship_isemergency` | integer | Whether this is an emergency contact (1=yes, 0=no) | `1` |
| `relationship_liveswith` | integer | Whether student lives with this contact (1=yes, 0=no) | `1` |
| `relationship_receivesmail` | integer | Whether contact receives mail (1=yes, 0=no) | `1` |
| `relationship_schoolpickup` | integer | Whether contact can pick up from school (1=yes, 0=no) | `1` |

## Sample Response

```json
{
  "QueryName": "com.fsenrollment.dats.person.relationship",
  "RecordCount": 100,
  "Records": [
    {
      "person_id": 12345,
      "person_dcid": 12400,
      "student_student_number": "123456",
      "student_dcid": 54321,
      "relationship_priority_order": 1,
      "relationship_isactive": 1,
      "relationship_iscustodial": 1,
      "relationship_isemergency": 1,
      "relationship_liveswith": 1,
      "relationship_receivesmail": 1,
      "relationship_schoolpickup": 1,
      "relationship_relationship_code": "Mother",
      "relationship_relationship_note": "Primary contact"
    },
    {
      "person_id": 12345,
      "person_dcid": 12400,
      "student_student_number": "789012",
      "student_dcid": 54322,
      "relationship_priority_order": 1,
      "relationship_isactive": 1,
      "relationship_iscustodial": 1,
      "relationship_isemergency": 1,
      "relationship_liveswith": 1,
      "relationship_receivesmail": 1,
      "relationship_schoolpickup": 1,
      "relationship_relationship_code": "Mother",
      "relationship_relationship_note": null
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
- `student_student_number`
- `student_dcid`
- `relationship_priority_order`

**Commonly Present:**
- `relationship_relationship_code` (should always be present)
- All relationship flags (default to 0 or 1)

**Optional Fields:**
- `relationship_relationship_note` (only when specified)

### Data Type Details

#### Boolean Fields (stored as integers)
- **Format**: `0` (false) or `1` (true)
- **Examples**: `relationship_isactive: 1`, `relationship_iscustodial: 0`
- **Note**: PowerSchool stores boolean values as integers

#### Priority Order
- **Format**: Integer starting at 1
- **Purpose**: Determines which contact is primary, secondary, etc.
- **Note**: Lower numbers indicate higher priority

#### Relationship Type Codes
- **Common Values**: `"Mother"`, `"Father"`, `"Guardian"`, `"Grandmother"`, `"Grandfather"`, `"Aunt"`, `"Uncle"`, `"Other"`
- **Note**: Actual values depend on PowerSchool codeset configuration

## Common Use Cases

### Get All Relationships for a Person
```powershell
$relationships = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords
$personRelationships = $relationships.Records | Where-Object { $_.person_id -eq 12345 }
```

### Get Primary Contacts Only
```powershell
$relationships = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords
$primaryContacts = $relationships.Records | Where-Object { $_.relationship_priority_order -eq 1 }
```

### Get Emergency Contacts
```powershell
$relationships = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords
$emergencyContacts = $relationships.Records | Where-Object { $_.relationship_isemergency -eq 1 }
```

### Get Custodial Parents
```powershell
$relationships = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords
$custodialParents = $relationships.Records | Where-Object { $_.relationship_iscustodial -eq 1 }
```

### Group Relationships by Person
```powershell
$relationships = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords
$relationshipsByPerson = $relationships.Records | Group-Object -Property person_id
```

### Export for Analysis
```powershell
$allRelationships = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords
$allRelationships.Records | Export-Csv -Path "relationships_export.csv" -NoTypeInformation
```

## Performance Considerations

- **Default Page Size**: 100 records per request
- **Typical Dataset**: Multiple records per person (one for each student they are associated with)
- **Pagination**: Use `-AllRecords` for complete datasets
- **Memory Usage**: Each record ~400-600 bytes

## Related Queries

This query is typically used in conjunction with:
- `com.fsenrollment.dats.person` to get basic person information
- `com.fsenrollment.dats.person.email` to get email addresses
- `com.fsenrollment.dats.person.phone` to get phone numbers
- `com.fsenrollment.dats.person.address` to get addresses

## PowerSchool Plugin Requirements

This query requires the FSEnrollment PowerSchool plugin with appropriate permissions for:
- Person table read access
- Student contact association table read access
- Student contact detail table read access
- Students table read access
- Codeset table read access (for relationship type codes)

See the plugin configuration files for detailed permission mappings.

## Change Detection

This query is used by the `Compare-PSContact` function to detect changes in student-contact relationships between CSV imports and PowerSchool data. Changes detected include:
- New relationships
- Modified relationship properties (priority order, flags, relationship type)
- Removed relationships
- Changes to custody, emergency contact, lives with, receives mail, and school pickup flags

## Notes

### Multiple Students
- A single person can have relationships with multiple students
- Each person-student pair will be a separate record
- Use `person_id` and `student_dcid` together to uniquely identify a relationship

### Relationship Priority
- Priority order determines which contact is primary for a student
- Priority 1 is typically the primary contact
- Multiple contacts can have the same priority in some cases

### Active vs Inactive Relationships
- The `relationship_isactive` flag indicates if the relationship is currently active
- Inactive relationships may still be in the system for historical purposes
