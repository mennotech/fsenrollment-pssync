# public functions

This directory contains all public (exported) functions for the fsenrollment-pssync module.

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
