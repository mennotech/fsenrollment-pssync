# PowerQuery Association IDs Update

**Date:** February 16, 2026  
**Impact:** Critical - Requires PowerQuery Plugin Update

## Overview

The PowerSchool Contact API requires **association IDs** (not entity IDs) for PUT and DELETE operations on emails, phones, and addresses. The PowerQuery definitions have been updated to include these association IDs. (v.1.1.8)

## Changes Made

### 1. PowerQuery XML Updates

**File:** `docs/powerschool api plugin/queries_root/com.fsenrollment.dats.person.named_queries.xml`

#### Email Query (`com.fsenrollment.dats.person.email`)

**Added Field:**
- `personemailaddressassoc.personemailaddressassocid AS emailaddress_contactEmailId`

**Purpose:** Provides the `contactEmailId` required for DELETE and PUT operations on email addresses.

#### Phone Query (`com.fsenrollment.dats.person.phone`)

**Added Field:**
- `personphonenumberassoc.personphonenumberassocid AS phonenumber_contactPhoneId`

**Purpose:** Provides the `contactPhoneId` required for DELETE and PUT operations on phone numbers.

#### Address Query (`com.fsenrollment.dats.person.address`)

**Added Field:**
- `personaddressassoc.personaddressassocid AS address_contactAddressId`

**Purpose:** Provides the `contactAddressId` required for DELETE and PUT operations on addresses.

### 2. Template Configuration Updates

**File:** `config/templates/fs_powerschool_nonapi_report_parents.psd1`

Added field mappings for the new association IDs:

```powershell
# EmailAddress mappings
@{ CSVColumn = '* PowerQuery *'; EntityProperty = 'ContactEmailID'; DataType = 'int'; PowerSchoolAPIField = 'emailaddress_contactEmailId' }

# PhoneNumber mappings
@{ CSVColumn = '* PowerQuery *'; EntityProperty = 'ContactPhoneID'; DataType = 'int'; PowerSchoolAPIField = 'phonenumber_contactPhoneId' }

# Address mappings
@{ CSVColumn = '* PowerQuery *'; EntityProperty = 'ContactAddressID'; DataType = 'int'; PowerSchoolAPIField = 'address_contactAddressId' }
```

**Note:** These fields are sourced from PowerQuery, not from CSV columns (hence `'* PowerQuery *'` as CSVColumn).

### 3. Submit-PSContactChange Updates

**File:** `fsenrollment-pssync/public/Submit-PSContactChange.ps1`

Updated all email, phone, and address operations to use association IDs:

**Before (incorrect):**
```powershell
# DELETE using entity ID (emailaddressid)
$emailId = $removedEmail.Email.emailaddress_id
DELETE /ws/contacts/{contactId}/emails/{emailId}  # ❌ 404 Not Found
```

**After (correct):**
```powershell
# DELETE using association ID (personemailaddressassocid)
$contactEmailId = $removedEmail.Email.emailaddress_contactEmailId
DELETE /ws/contacts/{contactId}/emails/{contactEmailId}  # ✅ Works!
```

## Why This Change Was Needed

### PowerSchool's Dual ID System

PowerSchool uses two types of IDs for many-to-many relationships:

| ID Type | Table Example | Purpose | API Usage |
|---------|---------------|---------|-----------|
| **Entity ID** | `emailaddress.emailaddressid` | References the email record itself | Reference only |
| **Association ID** | `personemailaddressassoc.personemailaddressassocid` | References the link between person and email | PUT, DELETE, GET operations |

### Previous Issue

The Contact API endpoints require the **association ID** for all operations:

- **POST** `/ws/contacts/{contactId}/emails` - Add new email (creates association)
- **PUT** `/ws/contacts/{contactId}/emails/{contactEmailId}` - Update email (needs association ID)
- **DELETE** `/ws/contacts/{contactId}/emails/{contactEmailId}` - Delete email (needs association ID)
- **GET** `/ws/contacts/{contactId}/emails/{contactEmailId}` - Get specific email (needs association ID)

### What Was Happening

1. PowerQuery was returning `emailaddressid` (entity ID = 2105)
2. Code attempted: `DELETE /ws/contacts/5856/emails/2105`
3. Result: **HTTP 404 Not Found** (because 2105 isn't a valid contactEmailId)
4. Correct ID: `contactEmailId` (association ID = 2256)
5. Working request: `DELETE /ws/contacts/5856/emails/2256` ✅

## Migration Steps

### Step 1: Update PowerQuery Plugin

1. Navigate to `docs/powerschool api plugin/`
2. Verify the updated `queries_root/com.fsenrollment.dats.person.named_queries.xml` contains the new association ID fields
3. Re-upload the plugin to PowerSchool:
   - PowerSchool > System Settings > Plugin Management Dashboard
   - Upload the updated plugin ZIP file
   - Verify plugin installs successfully

### Step 2: Re-Extract Data

After updating the PowerQuery plugin, re-run data extraction to populate the new fields:

```powershell
# Connect to PowerSchool
Import-Module ./fsenrollment-pssync/FSEnrollment-PSSync.psd1
Connect-PowerSchool

# Extract contact data with new association IDs
$emailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords
$phoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords
$addressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords

# Verify new fields are present
$emailData[0] | Get-Member -Name emailaddress_contactEmailId
$phoneData[0] | Get-Member -Name phonenumber_contactPhoneId
$addressData[0] | Get-Member -Name address_contactAddressId
```

### Step 3: Regenerate Change Detection Files

Any existing change detection JSON files will have the old ID fields. Regenerate them:

```powershell
# Run contact change detection
.\scripts\Example-ContactChangeDetection.ps1

# This will create new change JSON files with the correct association IDs
```

### Step 4: Test Submit Operations

```powershell
# Test with a single change
.\scripts\Example-ContactSubmitChanges.ps1 `
    -ChangeFilePath .\data\pending\2026-02-16-XXXX-contact-changes.json `
    -Limit 1 `
    -Verbose

# Verify operations succeed (should see HTTP 200 responses)
```

## Field Reference

### Email Fields

| Field Name | PowerQuery Source | Template Property | API Parameter |
|------------|-------------------|-------------------|---------------|
| `emailaddress_id` | `emailaddress.emailaddressid` | `EmailAddressID` | For reference only |
| `emailaddress_contactEmailId` | `personemailaddressassoc.personemailaddressassocid` | `ContactEmailID` | Required for PUT/DELETE |
| `emailaddress_emailAddress` | `emailaddress.emailaddress` | `EmailAddress` | Email address value |
| `emailaddress_isPrimary` | `personemailaddressassoc.isprimaryemailaddress` | `IsPrimary` | Primary flag |

### Phone Fields

| Field Name | PowerQuery Source | Template Property | API Parameter |
|------------|-------------------|-------------------|---------------|
| `phonenumber_id` | `phonenumber.phonenumberid` | `PhoneNumberID` | For reference only |
| `phonenumber_contactPhoneId` | `personphonenumberassoc.personphonenumberassocid` | `ContactPhoneID` | Required for PUT/DELETE |
| `phonenumber_phoneNumber` | `phonenumber.phonenumber` | `PhoneNumber` | Phone number value |
| `phonenumber_isPreferred` | `personphonenumberassoc.ispreferred` | `IsPreferred` | Preferred flag |

### Address Fields

| Field Name | PowerQuery Source | Template Property | API Parameter |
|------------|-------------------|-------------------|---------------|
| `address_id` | `personaddress.personaddressid` | `AddressID` | For reference only |
| `address_contactAddressId` | `personaddressassoc.personaddressassocid` | `ContactAddressID` | Required for PUT/DELETE |
| `address_street` | `personaddress.street` | `Street` | Street address |
| `address_city` | `personaddress.city` | `City` | City value |

## Error Messages

The code now includes helpful error messages if association IDs are missing:

**Email:**
```
Email deletion failed: Missing contactEmailId - ensure PowerQuery includes personemailaddressassoc.personemailaddressassocid
```

**Phone:**
```
Phone deletion failed: Missing contactPhoneId - ensure PowerQuery includes personphonenumberassoc.personphonenumberassocid
```

**Address:**
```
Address deletion failed: Missing contactAddressId - ensure PowerQuery includes personaddressassoc.personaddressassocid
```

These errors indicate the PowerQuery plugin needs to be updated.

## Troubleshooting

### Issue: Missing association ID fields

**Symptoms:**
- Error: "Missing contactEmailId"
- Change JSON files don't have `ContactEmailID`, `ContactPhoneID`, or `ContactAddressID` properties

**Solution:**
1. Verify PowerQuery plugin has been updated and re-installed in PowerSchool
2. Re-run `Invoke-PowerQuery` to extract fresh data with new fields
3. Regenerate change detection JSON files

### Issue: HTTP 404 on DELETE/PUT operations

**Symptoms:**
- DELETE or PUT operations return HTTP 404
- Error: "Not found"

**Solution:**
1. Verify you're using `contactEmailId` (association ID), not `emailId` (entity ID)
2. Check that change JSON file has the correct association ID values
3. Test with a simple GET to verify the association ID exists:
   ```powershell
   GET /ws/contacts/{contactId}/emails/{contactEmailId}
   ```

### Issue: Old change detection files

**Symptoms:**
- Change JSON files created before the PowerQuery update don't have association IDs

**Solution:**
- Delete old change detection JSON files from `data/pending/`
- Re-run change detection to generate new files with correct IDs

## Related Files

- **PowerQuery XML:** `docs/powerschool api plugin/queries_root/com.fsenrollment.dats.person.named_queries.xml`
- **Template Config:** `config/templates/fs_powerschool_nonapi_report_parents.psd1`
- **Submit Function:** `fsenrollment-pssync/public/Submit-PSContactChange.ps1`
- **Compare Functions:** `fsenrollment-pssync/private/Compare-ContactEmailFields.ps1`, `Compare-ContactPhoneFields.ps1`, `Compare-ContactAddressFields.ps1`

## Additional Notes

### Backwards Compatibility

This change is **not backwards compatible** with existing change detection JSON files. Any pending changes generated before this update must be regenerated.

### Similar Patterns in PowerSchool

This dual-ID pattern appears in many PowerSchool tables with many-to-many relationships:

- `student` ↔ `studentcontactassoc` ↔ `person` (contact relationships)
- `student` ↔ `cc` ↔ `sections` (course enrollments)
- `person` ↔ `personemailaddressassoc` ↔ `emailaddress` (contact emails)
- `person` ↔ `personphonenumberassoc` ↔ `phonenumber` (contact phones)
- `person` ↔ `personaddressassoc` ↔ `personaddress` (contact addresses)

Always use the **association table's ID** for PUT/DELETE operations in the Contact API.

### API Documentation Reference

See `docs/powerschool-api-docs/plugins/powerschool-api-contacts.md` for complete Contact API endpoint documentation, including parameter requirements for PUT and DELETE operations.
