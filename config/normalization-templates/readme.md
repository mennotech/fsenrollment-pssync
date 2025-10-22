# CSV Normalization Templates

This directory contains normalization templates that define how to map CSV columns from Final Site Enrollment to PowerSchool API field names.

## Overview

The CSV normalization system allows for flexible parsing of different CSV formats from Final Site Enrollment. Each template defines:

- **Field Mappings**: Maps CSV column names to PowerSchool API field names
- **Data Type Conversions**: Specifies expected data types for validation and conversion
- **Value Transformations**: Defines how to transform values (e.g., boolean conversions)
- **Validation Rules**: Specifies required fields and validation logic

## Template Structure

Templates are PowerShell data files (.psd1) with the following structure:

```powershell
@{
    # Template metadata
    Name = 'template_name'
    Description = 'Template description'
    Version = '1.0.0'
    SupportedTypes = @('students', 'parents', 'staff', 'courses', 'enrollments')
    
    # Field mappings for each data type
    Students = @{
        # PowerSchool API field = CSV column name(s) - first match wins
        student_number = @('studentNumber', 'Student_Number', 'StudentId', 'student_id')
        first_name = @('First_Name', 'FirstName', 'first_name')
        # ... more fields
    }
    
    Parents = @{
        # Parent/contact field mappings
    }
    
    # Data type conversions
    DataTypes = @{
        Students = @{
            school_id = 'int'
            grade_level = 'int'
        }
        Parents = @{
            is_active = 'bool'
        }
    }
    
    # Value transformations
    Transformations = @{
        BooleanTrue = @('1', 'true', 'yes', 'y', 'on')
        BooleanFalse = @('0', 'false', 'no', 'n', 'off', '')
    }
    
    # Validation rules
    Validation = @{
        Students = @{
            RequiredFields = @('student_number', 'first_name', 'last_name')
        }
    }
}
```

## Available Templates

### fs_powerschool_nonapi_report (Default)

The default normalization template for Final Site Enrollment CSV exports to PowerSchool API format.

**Supported Data Types:**
- Students
- Parents/Contacts

**Key Features:**
- Handles multiple column name variations (e.g., 'Student_Number', 'studentNumber', 'StudentId')
- Converts data types automatically (strings to integers, booleans)
- Validates required fields
- Supports both physical and mailing addresses for students
- Handles parent/contact relationships with students

## Using Templates

### Load a Template

```powershell
# Load the default template
$template = Get-CsvNormalizationTemplate

# Load a specific template
$template = Get-CsvNormalizationTemplate -TemplateName 'fs_powerschool_nonapi_report'

# Load from a custom path
$template = Get-CsvNormalizationTemplate -TemplateName 'custom' -TemplatesPath '/path/to/templates'
```

### Normalize CSV Data

```powershell
# Import and normalize student data
$students = Import-Csv './data/students.csv'
$normalized = ConvertTo-NormalizedData -CsvData $students -DataType 'students'

# Use a custom template
$template = Get-CsvNormalizationTemplate -TemplateName 'custom_format'
$normalized = ConvertTo-NormalizedData -CsvData $students -DataType 'students' -Template $template

# Skip validation
$normalized = ConvertTo-NormalizedData -CsvData $students -DataType 'students' -SkipValidation
```

### Pipeline Support

```powershell
# Normalize via pipeline
Import-Csv './data/students.csv' | ConvertTo-NormalizedData -DataType 'students'
```

## Creating Custom Templates

To create a new template:

1. Copy an existing template file (e.g., `fs_powerschool_nonapi_report.psd1`)
2. Rename it to your template name (e.g., `custom_format.psd1`)
3. Modify the field mappings to match your CSV format
4. Update the metadata (Name, Description, Version)
5. Save the file in the `config/normalization-templates/` directory

**Important Guidelines:**
- Use arrays for field mappings to support multiple column name variations
- The first matching column name in the array will be used
- Column name matching is case-sensitive by default
- Use consistent PowerSchool API field names across templates
- Include all necessary data type conversions
- Document any special transformations or requirements

## Field Mapping Details

### How Field Mapping Works

When normalizing data, the system:

1. Looks at each PowerSchool API field defined in the template
2. Checks the CSV columns against the list of possible column names
3. Uses the first matching column name found
4. Applies any data type conversions specified in the template
5. Validates against required fields if validation is enabled

### Example Mapping Process

For a student record:

```
CSV Column: "Student_Number"
Template Mapping: student_number = @('studentNumber', 'Student_Number', 'StudentId')
Result: Maps to 'student_number' field in normalized output
```

### Data Type Conversions

Supported data types:
- **int**: Converts strings to integers
- **bool**: Converts various string representations to boolean
- **date**: Converts strings to DateTime objects
- **string** (default): No conversion, preserves as string

## Validation

### Required Fields

Templates can specify required fields for each data type. During normalization:

- Missing required fields generate warnings
- Validation can be skipped with the `-SkipValidation` switch
- Validation errors are collected and reported at the end

### Example Validation Configuration

```powershell
Validation = @{
    Students = @{
        RequiredFields = @('student_number', 'first_name', 'last_name', 'school_id')
    }
    Parents = @{
        RequiredFields = @('id')
    }
}
```

## Testing Templates

Test your templates with Pester:

```powershell
# Run all normalization tests
Invoke-Pester -Path './fsenrollment-pssync/tests/CsvNormalization.Tests.ps1'

# Test with real data
$template = Get-CsvNormalizationTemplate -TemplateName 'your_template'
$testData = Import-Csv './data/examples/students_example.csv'
$normalized = ConvertTo-NormalizedData -CsvData $testData -DataType 'students' -Template $template -Verbose
```

## Troubleshooting

### Template Not Found

**Error**: `Template file not found: /path/to/template.psd1`

**Solution**: Ensure the template file exists in the correct directory and has the `.psd1` extension.

### Field Not Mapping

**Problem**: A CSV column is not being mapped to the expected API field.

**Solution**: 
1. Check the CSV column name (case-sensitive)
2. Add the column name to the template's field mapping array
3. Test with `-Verbose` to see mapping details

### Data Type Conversion Issues

**Problem**: Values are not converting to the expected type.

**Solution**:
1. Verify the data type is specified in the template's `DataTypes` section
2. Check that the CSV contains valid values for the target type
3. Use `-Verbose` to see conversion warnings

### Validation Errors

**Problem**: Getting warnings about missing required fields.

**Solution**:
1. Ensure the CSV contains all required fields
2. Check field mapping is correct
3. Use `-SkipValidation` if validation is too strict for your use case

## Best Practices

1. **Start with the default template**: The `fs_powerschool_nonapi_report` template covers common scenarios
2. **Use descriptive template names**: Name templates based on the CSV format or source
3. **Document custom templates**: Add clear descriptions and examples
4. **Test thoroughly**: Test templates with real CSV data before production use
5. **Version control**: Track template versions to manage changes over time
6. **Keep mappings flexible**: Include multiple column name variations to handle format changes
7. **Validate early**: Run validation during testing to catch data quality issues

## Examples

### Complete Workflow Example

```powershell
# 1. Load the module
Import-Module fsenrollment-pssync

# 2. Get the normalization template
$template = Get-CsvNormalizationTemplate -Verbose

# 3. Import CSV data
$studentsCSV = Import-Csv './data/incoming/students_2025-10-14.csv'

# 4. Normalize the data
$normalizedStudents = ConvertTo-NormalizedData `
    -CsvData $studentsCSV `
    -DataType 'students' `
    -Template $template `
    -Verbose

# 5. Review normalized data
$normalizedStudents | Select-Object -First 5 | Format-Table

# 6. Export to JSON for API submission
$normalizedStudents | ConvertTo-Json -Depth 10 | Out-File './data/processed/students_normalized.json'
```

### Multi-Type Normalization Example

```powershell
# Normalize multiple data types with the same template
$template = Get-CsvNormalizationTemplate

# Students
$students = Import-Csv './data/incoming/students.csv'
$normalizedStudents = ConvertTo-NormalizedData -CsvData $students -DataType 'students' -Template $template

# Parents
$parents = Import-Csv './data/incoming/parents.csv'
$normalizedParents = ConvertTo-NormalizedData -CsvData $parents -DataType 'parents' -Template $template

# Staff
$staff = Import-Csv './data/incoming/staff.csv'
$normalizedStaff = ConvertTo-NormalizedData -CsvData $staff -DataType 'staff' -Template $template
```

## See Also

- [Main Module Documentation](../../readme.md)
- [Data Processing Workflow](../../data/readme.md)
- [PowerSchool API Documentation](../../docs/readme.md)
