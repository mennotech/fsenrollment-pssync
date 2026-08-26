# public functions

This directory contains all public (exported) functions for the FSEnrollment-PSSync module.

## Guidelines

- All functions must follow PowerShell Verb-Noun naming convention
- Use approved PowerShell verbs (verify with `Get-Verb`)
- Each function should have complete comment-based help
- Functions should support pipeline input where appropriate
- Include proper parameter validation
- Use `Write-Verbose` and `Write-Debug` for diagnostic output

## Example Function Structure

```powershell
function Get-StudentData {
    <#
    .SYNOPSIS
        Brief description

    .DESCRIPTION
        Detailed description

    .PARAMETER ParameterName
        Parameter description

    .EXAMPLE
        Get-StudentData -ParameterName Value
        Description of example

    .NOTES
        Author: Mennotech
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ParameterName
    )

    # Function implementation
}
```

## Testing

All public functions must have corresponding Pester tests in the Tests directory.

## PowerSchool Contact Import Files

Use `Export-PSContactImportFile` to convert existing `PSNormalizedData` contact
collections into the PowerSchool Data Import Manager Student Contacts layout:

```powershell
$contactData = Import-FSCsv `
    -Path './data/examples/fs_powerschool_nonapi_report/parents_example.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_parents'

Export-PSContactImportFile -Data $contactData -Path './contacts.csv'
Export-PSContactImportFile -Data $contactData -Path './contacts.tsv'
```

The delimiter is inferred from the `.tsv` extension; use `-Format Csv` or
`-Format Tsv` to override it. The output includes only the 76-field import
header and data rows, omitting the instructional rows from PowerSchool's
template.
