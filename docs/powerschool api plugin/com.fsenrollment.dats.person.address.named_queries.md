# PowerQuery: com.fsenrollment.dats.person.address

## Overview

The `com.fsenrollment.dats.person.address` PowerQuery returns address records for persons from the PowerSchool person table. This query retrieves addresses with their associated metadata including type, priority order, and all address components (street, city, state, postal code, etc.).

## Usage

```powershell
# Basic execution (returns first 100 records)
$addressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address'

# Get all address records using pagination
$allAddressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords

# With verbose output to monitor progress
$addressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -Verbose
```

## Data Structure

The query returns records with the following structure:

**Note**: The PowerSchool API omits fields when they are null or empty rather than returning them with null values. Optional fields like `address_linetwo` and `address_unit` will only be present in the response when they contain data.

### Response Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `QueryName` | string | The name of the executed PowerQuery |
| `RecordCount` | integer | Number of address records returned |
| `Records` | array | Array of address record objects |
| `PaginationUsed` | boolean | Whether pagination was used (false for standard call) |
| `TotalRecords` | integer | Total available records (only when using `-AllRecords`) |

### Address Record Fields

Each record in the `Records` array contains the following fields:

#### Person Identifiers
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `person_id` | integer | Primary person ID | `12345` |
| `person_dcid` | integer | Person DCID (Data Collection ID) | `12400` |

#### Address Information
| Field Name | Type | Description | Example |
|------------|------|-------------|---------|
| `address_id` | integer | Unique address ID | `67890` |
| `address_street` | string | Street address line 1 | `"123 Main Street"` |
| `address_linetwo` | string | Street address line 2 (optional, omitted if null) | `"Apt 4B"` |
| `address_unit` | string | Unit/suite number (optional, omitted if null) | `"Suite 100"` |
| `address_city` | string | City name | `"Springfield"` |
| `address_state` | string | State/province code | `"CA"`, `"ON"` |
| `address_country` | string | Country code (optional) | `"US"`, `"CA"` |
| `address_postalcode` | string | ZIP/postal code | `"12345"`, `"M5V 3A8"` |
| `address_type` | string | Type of address | `"Home"`, `"Work"`, `"Mailing"` |
| `address_order` | integer | Priority order (1 = highest priority) | `1` |

## Sample Response

```json
{
  "QueryName": "com.fsenrollment.dats.person.address",
  "RecordCount": 100,
  "Records": [
    {
      "_name": "PersonAddress",
      "address_postalcode": "12345",
      "address_type": "Home",
      "address_country": "US",
      "address_id": 53,
      "address_state": "CA",
      "address_city": "Springfield",
      "address_street": "123 Main Street",
      "address_order": 1,
      "_id": 1151,
      "person_dcid": 1201,
      "person_id": 1151
    },
    {
      "_name": "PersonAddress", 
      "address_id": 67891,
      "address_street": "456 Oak Avenue",
      "address_linetwo": "Suite 200",
      "address_city": "Los Angeles",
      "address_state": "CA",
      "address_country": "US",
      "address_postalcode": "90001",
      "address_type": "Work",
      "address_order": 2,
      "_id": 12345,
      "person_dcid": 12400,
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
- `address_id`
- `address_street`
- `address_city`

**Commonly Present:**
- `address_type` (should always be present)
- `address_order` (defaults to system-assigned value)
- `address_state` (present for most addresses)
- `address_postalcode` (present for most addresses)

**Optional Fields:**
- `address_linetwo` (only when specified)
- `address_unit` (only when specified)
- `address_country` (may be null if not specified)

### Data Type Details

#### Priority Order
- **Format**: Integer starting at 1
- **Purpose**: Determines display order and preference
- **Note**: Lower numbers indicate higher priority

#### State/Province Codes
- **Format**: Two-letter abbreviation
- **Examples**: `"CA"`, `"NY"`, `"ON"`, `"BC"`
- **Note**: Format depends on country

#### Country Codes
- **Format**: Two-letter ISO country code
- **Examples**: `"US"`, `"CA"`, `"MX"`
- **Note**: May be null if not specified in PowerSchool

#### Postal Codes
- **Format**: Varies by country
- **US ZIP**: `"12345"` or `"12345-6789"`
- **Canada**: `"M5V 3A8"`
- **Note**: Format validation depends on PowerSchool configuration

#### Address Type Codes
- **Common Values**: `"Home"`, `"Work"`, `"Mailing"`, `"Physical"`, `"Other"`
- **Note**: Actual values depend on PowerSchool codeset configuration

## Common Use Cases

### Get Primary Address for Each Person
```powershell
$addresses = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$primaryAddresses = $addresses.Records | Where-Object { $_.address_order -eq 1 }
```

### Get Home Addresses Only
```powershell
$addresses = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$homeAddresses = $addresses.Records | Where-Object { $_.address_type -eq "Home" }
```

### Group Addresses by Person
```powershell
$addresses = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$addressesByPerson = $addresses.Records | Group-Object -Property person_id
```

### Find Addresses by State
```powershell
$addresses = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$caAddresses = $addresses.Records | Where-Object { $_.address_state -eq "CA" }
```

### Export for Analysis
```powershell
$allAddresses = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$allAddresses.Records | Export-Csv -Path "addresses_export.csv" -NoTypeInformation
```

### Build Full Address String
```powershell
$addresses = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords
$addresses.Records | ForEach-Object {
    $fullAddress = $_.address_street
    if ($_.address_linetwo) { $fullAddress += ", " + $_.address_linetwo }
    if ($_.address_unit) { $fullAddress += ", " + $_.address_unit }
    $fullAddress += ", " + $_.address_city + ", " + $_.address_state + " " + $_.address_postalcode
    [PSCustomObject]@{
        PersonId = $_.person_id
        FullAddress = $fullAddress
    }
}
```

## Performance Considerations

- **Default Page Size**: 100 records per request
- **Typical Dataset**: Multiple records per person (varies by contact data completeness)
- **Pagination**: Use `-AllRecords` for complete datasets
- **Memory Usage**: Each record ~500-700 bytes

## Related Queries

This query is typically used in conjunction with:
- `com.fsenrollment.dats.person` to get basic person information
- `com.fsenrollment.dats.person.email` to get email addresses
- `com.fsenrollment.dats.person.phone` to get phone numbers

## PowerSchool Plugin Requirements

This query requires the FSEnrollment PowerSchool plugin with appropriate permissions for:
- Person table read access
- Person address table read access
- Person address association table read access
- Codeset table read access (for address type, state, and country codes)

See the plugin configuration files for detailed permission mappings.

## Change Detection

This query is used by the `Compare-PSContact` function to detect changes in addresses between CSV imports and PowerSchool data. Changes detected include:
- New addresses
- Modified street addresses
- Changes to address line two
- Changes to unit/suite
- Changes to city
- Changes to state/province
- Changes to country
- Changes to postal code
- Changes to address type
- Changes to priority order

## Notes

### Address Comparison Considerations

When comparing addresses:
- Whitespace normalization is important
- Case sensitivity should be handled
- Abbreviations (St vs Street) may need normalization
- Directional prefixes (N, S, E, W) should be standardized
- Postal code formatting may vary (with/without spaces or hyphens)
