# scripts

This directory contains utility scripts and standalone PowerShell scripts that support the FSEnrollment-PSSync module.

## Purpose

- Maintenance scripts
- One-time migration scripts
- Deployment scripts
- Development helper scripts
- Scripts that orchestrate multiple module functions

## Guidelines

- Scripts should be well-documented with comment-based help
- Use `#Requires` statements to specify PowerShell version and required modules
- Scripts should handle errors gracefully
- Log important operations
- Follow the same coding standards as module functions
- Use PascalCase-with-hyphens naming (e.g., `Sync-PowerSchoolData.ps1`)

## Example Script Structure

```powershell
#Requires -Version 7.0
#Requires -Modules FSEnrollment-PSSync

<#
.SYNOPSIS
    Brief description of the script

.DESCRIPTION
    Detailed description of what the script does

.PARAMETER ParameterName
    Description of parameter

.EXAMPLE
    ./Script-Name.ps1 -ParameterName Value
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

# Script implementation
```

## Usage

Scripts in this directory are typically run directly or scheduled as automated tasks.
