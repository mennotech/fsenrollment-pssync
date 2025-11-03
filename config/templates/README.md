# CSV Template Configurations

This directory contains template configuration files that define how to parse different CSV formats from Final Site Enrollment and normalize them into PowerSchool data structures.

## Overview

Each template is a PowerShell Data File (.psd1) that maps CSV columns to PowerSchool entity properties with data type information. Templates can use either standard column mappings or custom parser functions for complex formats.

## Template Structure

A template configuration contains:
- **TemplateName**: Unique identifier for the template
- **Description**: Human-readable description of the template
- **EntityType**: PowerShell class name for the entity (e.g., 'PSStudent', 'PSNormalizedData')
- **CustomParser**: (Optional) Name of a custom parser function for complex CSV formats
- **ColumnMappings**: Column mappings from CSV to entity properties
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
    CustomParser = $null
    # EntityType is inherited from template-level setting for all mappings
    ColumnMappings = @(
        @{ CSVColumn = 'CSV_Column_Name'; EntityProperty = 'PropertyName'; DataType = 'string' }
        # ... more mappings (no EntityType needed in each mapping)
    )
}
```

### Custom Parser Format

For complex CSV formats (multi-row, conditional logic, etc.), create a custom parser function in the templates folder and reference it in the template:

**Template Configuration:**
```powershell
@{
    TemplateName = 'template_name'
    Description = 'Template description'
    EntityType = 'PSNormalizedData'
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
- **Usage**: `Import-FSParentsCsv -Path parents.csv`
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
