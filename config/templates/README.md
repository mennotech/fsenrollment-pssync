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
- **ColumnMappings**: Array of mappings from CSV columns to entity properties (used when CustomParser is not specified)

### Standard Template Format

For simple CSV formats with one entity per row, use column mappings:

```powershell
@{
    TemplateName = 'template_name'
    Description = 'Template description'
    EntityType = 'PSStudent'
    CustomParser = $null
    ColumnMappings = @(
        @{ CSVColumn = 'CSV_Column_Name'; EntityProperty = 'PropertyName'; DataType = 'string' }
        # ... more mappings
    )
}
```

### Custom Parser Format

For complex CSV formats (multi-row, conditional logic, etc.), specify a custom parser function:

```powershell
@{
    TemplateName = 'template_name'
    Description = 'Template description'
    EntityType = 'PSNormalizedData'
    CustomParser = 'Import-CustomParserFunction'
    ColumnMappings = @()
}
```

The custom parser function receives the CSV data and returns a PSNormalizedData object:

```powershell
function Import-CustomParserFunction {
    param([object[]]$CsvData)
    # Custom parsing logic here
    return [PSNormalizedData]::new()
}
```

## Available Templates

### fs_powerschool_nonapi_report_students.psd1

Maps student data from Final Site Enrollment's PowerSchool Non-API Report students export.

- **Entity Type**: PSStudent
- **Parser Type**: Standard column mappings
- **Usage**: `Import-FSStudentsCsv -Path students.csv`
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
