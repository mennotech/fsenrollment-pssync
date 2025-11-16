# Scripts

This directory contains utility scripts and standalone PowerShell scripts that support the FSEnrollment-PSSync module.

## Main Scripts

### Change Detection Scripts
- **`Example-ChangeDetection.ps1`** - Detects changes in student data between CSV and PowerSchool
- **`Example-ContactChangeDetection.ps1`** - Detects changes in contact/parent data
- **`Generate-ChangeDetectionHtmlReport.ps1`** - Creates comprehensive HTML reports from change detection results

### Data Processing Scripts
- **`Test-PowerQuery.ps1`** - Tests PowerQuery functionality
- **`Anonymize-ParentsExampleFile.ps1`** - Anonymizes parent data for examples
- **`Filter-ParentsByStudentExampleFile.ps1`** - Filters parent data by student criteria

## Output File Naming Convention

All output files use date-first naming for better sorting:
- JSON files: `yyyy-MM-dd-HHmm-description.json` (e.g., `2025-11-15-1430-student-changes.json`)
- HTML reports: `yyyy-MM-dd-HHmm-description.html` (e.g., `2025-11-15-1430-change-detection-report.html`)

## Directory Structure

Scripts output to organized data directories:
- `../data/pending/` - Change detection JSON files
- `../data/reports/` - HTML reports  
- `../data/processed/` - Processed files
- `../data/archive/` - Archived files

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
