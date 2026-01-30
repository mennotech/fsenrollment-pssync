# DateTime Format Configuration

## Overview

The FSEnrollment-PSSync module now supports configurable datetime format parsing to handle different date formats that may be exported from FinalSite based on location settings.

## Problem

Previously, datetime fields were parsed using `[datetime]::Parse()` which relied on the system's culture settings. This caused issues when:

- FinalSite exports changed from MM/dd/yyyy to dd/MM/yyyy format due to location settings
- Systems had different culture settings than the CSV format
- Ambiguous dates like 01/02/2025 could be interpreted as January 2nd or February 1st

## Solution

The solution adds a `DateTimeFormat` configuration parameter to template files that specifies the exact format expected in the CSV data.

### Template Configuration

Add a `DateTimeFormat` property to your template configuration file:

```powershell
@{
    TemplateName = 'fs_powerschool_nonapi_report_students'
    Description = 'Final Site Enrollment PowerSchool Non-API Report - Students Export'
    EntityType = 'PSStudent'
    # DateTime format used in CSV files (adjust based on FinalSite location settings)
    # Common formats: 'MM/dd/yyyy' (US), 'dd/MM/yyyy' (International), 'yyyy-MM-dd' (ISO)
    DateTimeFormat = 'MM/dd/yyyy'
    # ... rest of configuration
}
```

### Common DateTime Format Patterns

| Format | Description | Example |
|--------|-------------|---------|
| `MM/dd/yyyy` | US format (month/day/year) | 12/31/2025 |
| `dd/MM/yyyy` | International format (day/month/year) | 31/12/2025 |
| `yyyy-MM-dd` | ISO format (year-month-day) | 2025-12-31 |
| `M/d/yyyy` | US format without leading zeros | 1/5/2025 |
| `d/M/yyyy` | International without leading zeros | 5/1/2025 |
| `MM-dd-yyyy` | US format with dashes | 12-31-2025 |
| `dd-MM-yyyy` | International with dashes | 31-12-2025 |

### How It Works

1. **Template Loading**: When a template is loaded, the `DateTimeFormat` is read from the configuration
2. **Column Mapping**: The `Invoke-ColumnMapping` function receives the datetime format parameter
3. **Parsing**: For datetime fields, `[datetime]::ParseExact()` is used with the specified format instead of culture-dependent `[datetime]::Parse()`
4. **Error Handling**: If parsing fails, a warning is logged with the format that was expected

### Backward Compatibility

If `DateTimeFormat` is not specified in the template:
- The system falls back to `[datetime]::Parse()` for backward compatibility
- Existing templates continue to work without modification

### Configuration Examples

#### US Format (MM/dd/yyyy)
```powershell
DateTimeFormat = 'MM/dd/yyyy'
```
Parses: 12/31/2025, 01/05/2025

#### International Format (dd/MM/yyyy)
```powershool
DateTimeFormat = 'dd/MM/yyyy'
```
Parses: 31/12/2025, 05/01/2025

#### ISO Format (yyyy-MM-dd)
```powershell
DateTimeFormat = 'yyyy-MM-dd'
```
Parses: 2025-12-31, 2025-01-05

### Troubleshooting

#### Date Parsing Warnings
If you see warnings like:
```
WARNING: Failed to convert '31/12/2025' to datetime using format 'MM/dd/yyyy' for property DOB
```

**Solution**: Update your template's `DateTimeFormat` to match the actual format in your CSV:
```powershell
DateTimeFormat = 'dd/MM/yyyy'  # Change from MM/dd/yyyy
```

#### Mixed Date Formats
If your CSV contains mixed date formats, you may need to:
1. Standardize the export from FinalSite, or
2. Pre-process the CSV to normalize date formats, or  
3. Create separate templates for different date formats

### Best Practices

1. **Document the Format**: Always comment which format you're using and why
2. **Test with Real Data**: Verify the format matches your actual CSV exports
3. **Monitor Warnings**: Watch for date parsing warnings that indicate format mismatches
4. **Location Awareness**: Consider that FinalSite location settings may affect date formats
5. **Version Control**: Track changes to date formats in your template files

### Migration Guide

To update existing templates:

1. **Identify Current Format**: Look at your CSV files to determine the current date format
2. **Add Configuration**: Add the `DateTimeFormat` property to your template
3. **Test Parsing**: Run imports and check for date parsing warnings
4. **Adjust Format**: Update the format if you see warnings

Example migration:
```powershell
# Before
@{
    TemplateName = 'my_template'
    # ... other properties
}

# After  
@{
    TemplateName = 'my_template'
    DateTimeFormat = 'MM/dd/yyyy'  # Add this line
    # ... other properties
}
```