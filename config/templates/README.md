# CSV Template Configurations

This directory contains template configuration files that define how to parse different CSV formats from Final Site Enrollment and normalize them into PowerSchool data structures.

## Overview

Each template is a PowerShell Data File (.psd1) that maps CSV columns to PowerSchool entity properties with data type information. Templates can use either standard column mappings or custom parser functions for complex formats.

## Template Structure

A template configuration contains:
- **TemplateName**: Unique identifier for the template
- **Description**: Human-readable description of the template
- **EntityType**: PowerShell class name for the entity (e.g., 'PSStudent', 'PSNormalizedData')
- **DateTimeFormat**: (Optional) DateTime format string for parsing date fields (e.g., 'MM/dd/yyyy', 'dd/MM/yyyy')
- **KeyField**: Entity property used for matching records between CSV and PowerSchool
- **PowerSchoolKeyField**: PowerSchool API field that corresponds to the KeyField (e.g., 'local_id')
- **PowerSchoolKeyDataType**: Data type for the PowerSchool key field (e.g., 'int', 'string')
- **CheckForChanges**: Array of entity properties to monitor for changes during comparison
- **CustomParser**: (Optional) Name of a custom parser function for complex CSV formats
- **ColumnMappings**: Column mappings from CSV to entity properties with PowerSchool API field paths
  - For simple formats: Array of mappings (EntityType inherited from template)
  - For complex formats: Hashtable organized by entity type
- **EntityTypeMap**: (Optional, for complex formats) Maps hashtable keys to EntityType class names

### Standard Template Format

For simple CSV formats with one entity per row, use column mappings with EntityType inherited from the template:

```powershell
@{
    TemplateName = 'template_name'
    Description = 'Template description'
    EntityType = 'PSStudent'
    # DateTime format for parsing date fields (adjust based on FinalSite location settings)
    DateTimeFormat = 'MM/dd/yyyy'  # US format, use 'dd/MM/yyyy' for international
    # Key field for matching records between CSV and PowerSchool
    KeyField = 'StudentNumber'
    PowerSchoolKeyField = 'local_id'
    PowerSchoolKeyDataType = 'int'
    # Fields to check for changes during comparison
    CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'Street', 'City', 'State', 'Zip')
    CustomParser = $null
    # EntityType is inherited from template-level setting for all mappings
    # IMPORTANT: PowerSchoolAPIField specifies the PowerQuery field name for data retrieval and comparison
    # For Students: Use REST API field paths (e.g., 'name.first_name', '@demographics.birth_date')
    # For Contacts: Use PowerQuery field names (e.g., 'person_firstName', 'emailaddress_emailAddress')
    # The submit functions handle field name conversion when syncing changes back to PowerSchool
    ColumnMappings = @(
        @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; DataType = 'string'; PowerSchoolAPIField = 'local_id'; PowerSchoolDataType = 'int' }
        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; DataType = 'string'; PowerSchoolAPIField = 'name.first_name' }
        @{ CSVColumn = 'DOB'; EntityProperty = 'DOB'; DataType = 'datetime'; PowerSchoolAPIField = '@demographics.birth_date' }
        @{ CSVColumn = 'Street'; EntityProperty = 'Street'; DataType = 'string'; PowerSchoolAPIField = '@addresses.physical.street' }
        # ... more mappings (no EntityType needed in each mapping)
    )
}
```

### PowerSchoolAPIField Naming Convention

**IMPORTANT**: The `PowerSchoolAPIField` property has different formats depending on the entity type:

1. **For Student data** (using REST API):
   - Format: REST API field paths
   - Examples: `'local_id'`, `'name.first_name'`, `'@demographics.birth_date'`
   - Used for both retrieval via GET /ws/v1/student/{id} and updates via PATCH

2. **For Contact data** (using PowerQuery Data Access API):
   - Format: PowerQuery flat field names with entity prefix
   - Examples: `'person_firstName'`, `'person_lastName'`, `'emailaddress_emailAddress'`, `'phonenumber_phoneNumber'`
   - Used for retrieval via PowerQuery (com.fsenrollment.dats.person, etc.)
   - **Note**: When submitting updates, Submit-PSContactChange converts these to REST API format automatically

**Why the difference?**
- Students use PowerSchool's REST API directly for both retrieval and updates
- Contacts use PowerQuery for efficient bulk retrieval but REST API for updates
- The conversion is handled automatically by the submit functions

**Common pitfall**: Don't confuse PowerQuery field names (`person_firstName`) with REST API field names (`firstName`). The template always uses PowerQuery format for contacts, and the code handles conversion during updates.

### Custom Parser Format

For complex CSV formats (multi-row, conditional logic, etc.), create a custom parser function in the templates folder and reference it in the template:

**Template Configuration:**
```powershell
@{
    TemplateName = 'template_name'
    Description = 'Template description'
    EntityType = 'PSNormalizedData'
    # DateTime format for parsing date fields
    DateTimeFormat = 'MM/dd/yyyy'
    CustomParser = 'Import-CustomParserFunction'
    # EntityTypeMap defines entity types for hashtable keys
    EntityTypeMap = @{
        Contact = 'PSContact'
        EmailAddress = 'PSEmailAddress'
        PhoneNumber = 'PSPhoneNumber'
    }
    # ColumnMappings organized by entity type (EntityType inferred from hashtable key via EntityTypeMap)
    ColumnMappings = @{
        Contact = @(
            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; DataType = 'string' }
            # ... more contact mappings
        )
        EmailAddress = @(
            @{ CSVColumn = 'Email'; EntityProperty = 'EmailAddress'; DataType = 'string' }
            # ... more email mappings
        )
        PhoneNumber = @(
            @{ CSVColumn = 'Phone'; EntityProperty = 'PhoneNumber'; DataType = 'string' }
            # ... more phone mappings
        )
    }
}
```

**Custom Parser File (config/templates/Import-CustomParserFunction.ps1):**
```powershell
function Import-CustomParserFunction {
    param(
        [object[]]$CsvData,
        [hashtable]$TemplateConfig
    )
    
    # Access entity-specific mappings from template
    $contactMappings = $TemplateConfig.ColumnMappings.Contact
    $emailMappings = $TemplateConfig.ColumnMappings.EmailAddress
    
    # Custom parsing logic here using Apply-ColumnMappings private function
    $normalizedData = [PSNormalizedData]::new()
    
    foreach ($row in $CsvData) {
        $contact = [PSContact]::new()
        Apply-ColumnMappings -CsvRow $row -Entity $contact -ColumnMappings $contactMappings
        $normalizedData.Contacts.Add($contact)
    }
    
    return $normalizedData
}
```

The custom parser is stored alongside the template configuration in the `config/templates/` folder. This keeps format-specific parsing logic separate from the generic import functions in the module.

## Design Benefits

### Simplified Configuration

- **Simple formats**: No redundant EntityType in each column mapping (inherited from template)
- **Complex formats**: EntityType inferred from hashtable key via EntityTypeMap
- **Less repetition**: Cleaner, more maintainable configuration files

### Separation of Concerns

- **Generic logic**: Module functions handle CSV import orchestration
- **Format-specific logic**: Templates define mappings, custom parsers handle complex formats
- **Shared utilities**: Apply-ColumnMappings function used by both standard and custom parsers

## Available Templates

### fs_powerschool_nonapi_report_students.psd1

Maps student data from Final Site Enrollment's PowerSchool Non-API Report students export.

- **Entity Type**: PSStudent
- **Parser Type**: Standard column mappings (EntityType inherited from template)
- **Usage**: `Import-FSCsv -Path students.csv -TemplateName 'fs_powerschool_nonapi_report_students'`
- **Format**: Standard CSV with one row per student

**Mapped Fields**:
- Student demographics (name, gender, DOB)
- Enrollment information (school, grade, status)
- Contact information (phone, addresses)
- Scheduling information

### fs_powerschool_nonapi_report_parents.psd1

Maps parent/contact data from Final Site Enrollment's PowerSchool Non-API Report parents export.

- **Entity Type**: PSNormalizedData
- **Parser Type**: Custom parser (`Import-FSParentsCustomParser`)
- **Usage**: `Import-FSCsv -Path parents.csv -TemplateName 'fs_powerschool_nonapi_report_parents'`
- **Format**: Complex multi-row format

**Multi-row format handled by custom parser**:
- **Contact rows**: Full contact information (name, email, primary phone, address)
- **Additional phone rows**: Same contact ID, only phone data
- **Relationship rows**: Identified by presence of studentNumber field

**Entity Types Created**:
- PSContact
- PSEmailAddress
- PSPhoneNumber
- PSAddress
- PSStudentContactRelationship

**Optional Exclusion Feature**:

The template supports excluding contacts from import using an optional CSV column. To enable this feature, configure the `ExcludeColumnName` property in the template:

```powershell
# Optional: Set the CSV column name for excluding contacts
ExcludeColumnName = 'Exclude from PowerSchool Export'
```

When configured and the column exists in the CSV:
- Contacts with the exclude column set to TRUE/true/1/yes are skipped
- All associated data (emails, phones, addresses, relationships) are also excluded
- If the column name is omitted from the template, the exclusion feature is disabled
- If the column doesn't exist in the CSV, all contacts are imported normally

**Example CSV with exclusion**:
```csv
New Contact Identifier,First Name,Last Name,...,Exclude from PowerSchool Export
abc-123,John,Smith,...,false
def-456,Jane,Doe,...,true    # This contact will be excluded
def-456,,,,...,              # Additional phone row - auto-excluded
def-456,,,,...,              # Relationship row - auto-excluded
```

## Creating New Templates

To add support for a new CSV format:

1. Create a new .psd1 file in this directory (e.g., `new_format.psd1`)
2. Define the template structure with TemplateName, Description, EntityType
3. Map each CSV column to the corresponding PowerSchool entity property
4. Specify the data type for each mapping
5. Create or update the import function to use the template

### Example

```powershell
@{
    TemplateName = 'new_format'
    Description = 'Description of the new format'
    EntityType = 'PSStudent'
    ColumnMappings = @(
        @{ CSVColumn = 'StudentID'; EntityProperty = 'StudentNumber'; DataType = 'string' }
        @{ CSVColumn = 'FirstName'; EntityProperty = 'FirstName'; DataType = 'string' }
        # ... more mappings
    )
}
```

## PowerSchool API Field Mapping

### PowerSchoolAPIField Syntax

The `PowerSchoolAPIField` property in column mappings defines how the field maps to PowerSchool's API structure. This is critical for:
1. **Change detection**: Comparing CSV data with PowerSchool API responses
2. **Change application**: Syncing updates back to PowerSchool via API
3. **Automatic expansion detection**: System automatically detects required API expansions

**Syntax Options:**

1. **Standard fields** (top-level API fields):
   ```powershell
   PowerSchoolAPIField = 'local_id'
   PowerSchoolAPIField = 'student_number'
   ```

2. **Nested fields** (dot notation for nested objects):
   ```powershell
   PowerSchoolAPIField = 'name.first_name'
   PowerSchoolAPIField = 'name.middle_name'
   PowerSchoolAPIField = 'name.last_name'
   ```

3. **Expansion fields** (prefix with `@` - requires API expansion parameter):
   ```powershell
   PowerSchoolAPIField = '@demographics.birth_date'
   PowerSchoolAPIField = '@demographics.gender'
   PowerSchoolAPIField = '@addresses.physical.street'
   PowerSchoolAPIField = '@addresses.physical.city'
   PowerSchoolAPIField = '@addresses.mailing.street'
   ```
   When the system detects `@addresses` fields, it automatically adds `addresses` to the expansions parameter.

4. **Extension fields** (custom PowerSchool extensions):
   ```powershell
   PowerSchoolAPIField = 'extension.u_students_extension.legal_first_name'
   PowerSchoolAPIField = 'extension.studentcorefields.state_studentnumber'
   ```
   When the system detects `extension.table_name` fields, it automatically adds `table_name` to the extensions parameter.

### Automatic Expansion/Extension Detection

The `Get-RequiredPowerSchoolFields` function analyzes your template's `PowerSchoolAPIField` mappings and automatically determines which expansions and extensions are required:

```powershell
$csvData = Import-FSCsv -Path './students.csv' -TemplateName 'your_template'
$required = Get-RequiredPowerSchoolFields -TemplateMetadata $csvData.TemplateMetadata
# Returns: @{ Extensions = @('u_students_extension'); Expansions = @('demographics', 'addresses') }

$psStudents = Get-PowerSchoolStudent -All `
    -Extensions $required.Extensions `
    -Expansions $required.Expansions
```

### CheckForChanges Configuration

The `CheckForChanges` array specifies which entity properties should be monitored for differences during comparison:

```powershell
CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'Street', 'City', 'State', 'Zip')
```

- Only fields listed in `CheckForChanges` are compared between CSV and PowerSchool data
- If a field changes, it's included in the `Updated` results from `Compare-PSStudent`
- Fields must have `PowerSchoolAPIField` mappings to be properly compared and synced
- Add all fields you want to monitor, including address, demographic, and enrollment fields

## Data Type Conversion

Supported data types:
- **string**: Text values (default if not specified)
- **int**: Integer numbers
- **bool**: Boolean values (supports '0'/'1', 'true'/'false')
- **datetime**: Date and time values

The `ConvertFrom-CsvRow` helper function handles all data type conversions automatically.

## PowerSchool Entity Classes

The following entity classes are available:
- **PSStudent**: Student demographic and enrollment data
- **PSContact**: Parent/guardian contact information
- **PSEmailAddress**: Email addresses linked to contacts
- **PSPhoneNumber**: Phone numbers linked to contacts
- **PSAddress**: Physical addresses linked to contacts
- **PSStudentContactRelationship**: Student-to-contact relationships with flags

See `fsenrollment-pssync/classes/PowerSchoolEntities.ps1` for complete entity definitions.
