<#
.SYNOPSIS
    Example script demonstrating CSV normalization usage.

.DESCRIPTION
    This script demonstrates how to use the CSV normalization functions
    to parse Final Site Enrollment CSV files and normalize them to
    PowerSchool API format.

.PARAMETER CsvPath
    Path to the CSV file to normalize. Defaults to the students example file.

.PARAMETER DataType
    The type of data in the CSV file (students, parents, staff, courses, enrollments).

.PARAMETER OutputPath
    Optional path to export the normalized data as JSON.

.EXAMPLE
    ./Example-CsvNormalization.ps1
    Normalizes the example students CSV file.

.EXAMPLE
    ./Example-CsvNormalization.ps1 -CsvPath ./data/incoming/students.csv -DataType students
    Normalizes a specific students CSV file.

.EXAMPLE
    ./Example-CsvNormalization.ps1 -CsvPath ./data/incoming/parents.csv -DataType parents -OutputPath ./data/processed/parents_normalized.json
    Normalizes parents data and exports to JSON.

.NOTES
    Author: Mennotech
    Requires: PowerShell 7.0+, fsenrollment-pssync module
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = './data/examples/students_example.csv',

    [Parameter(Mandatory = $false)]
    [ValidateSet('students', 'parents', 'staff', 'courses', 'enrollments')]
    [string]$DataType = 'students',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "CSV Normalization Example" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

try {
    # Import the module
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $moduleRoot 'fsenrollment-pssync/fsenrollment-pssync.psd1'
    
    if (-not (Test-Path $modulePath)) {
        throw "Module not found at: $modulePath"
    }

    Write-Host "Loading fsenrollment-pssync module..." -ForegroundColor Yellow
    Import-Module $modulePath -Force
    Write-Host "Module loaded successfully" -ForegroundColor Green
    Write-Host ""

    # Resolve CSV path
    $resolvedCsvPath = if ([System.IO.Path]::IsPathRooted($CsvPath)) {
        $CsvPath
    } else {
        Join-Path $moduleRoot $CsvPath
    }

    if (-not (Test-Path $resolvedCsvPath)) {
        throw "CSV file not found: $resolvedCsvPath"
    }

    Write-Host "Input CSV: $resolvedCsvPath" -ForegroundColor Yellow
    Write-Host "Data Type: $DataType" -ForegroundColor Yellow
    Write-Host ""

    # Load the normalization template
    Write-Host "Loading normalization template..." -ForegroundColor Yellow
    $template = Get-CsvNormalizationTemplate -Verbose
    Write-Host "Template: $($template.Name) v$($template.Version)" -ForegroundColor Green
    Write-Host ""

    # Import CSV data
    Write-Host "Importing CSV data..." -ForegroundColor Yellow
    $csvData = Import-Csv -LiteralPath $resolvedCsvPath
    Write-Host "Loaded $($csvData.Count) records" -ForegroundColor Green
    
    if ($csvData.Count -gt 0) {
        Write-Host "CSV Columns: $($csvData[0].PSObject.Properties.Name -join ', ')" -ForegroundColor Gray
    }
    Write-Host ""

    # Normalize the data
    Write-Host "Normalizing data..." -ForegroundColor Yellow
    $normalized = ConvertTo-NormalizedData -CsvData $csvData -DataType $DataType -Template $template -Verbose
    Write-Host "Normalized $($normalized.Count) records" -ForegroundColor Green
    Write-Host ""

    # Show sample of normalized data
    Write-Host "Sample Normalized Record (first record):" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    if ($normalized.Count -gt 0) {
        $normalized[0] | Format-List
    }

    # Show field mapping summary
    Write-Host ""
    Write-Host "Field Mapping Summary:" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    if ($normalized.Count -gt 0) {
        $fields = $normalized[0].PSObject.Properties
        $populatedFields = $fields | Where-Object { $null -ne $_.Value -and $_.Value -ne '' } | Select-Object -ExpandProperty Name
        $emptyFields = $fields | Where-Object { $null -eq $_.Value -or $_.Value -eq '' } | Select-Object -ExpandProperty Name
        
        Write-Host "Populated fields ($($populatedFields.Count)): $($populatedFields -join ', ')" -ForegroundColor Green
        if ($emptyFields.Count -gt 0) {
            Write-Host "Empty/null fields ($($emptyFields.Count)): $($emptyFields -join ', ')" -ForegroundColor Yellow
        }
    }
    Write-Host ""

    # Export to JSON if requested
    if ($OutputPath) {
        $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
            $OutputPath
        } else {
            Join-Path $moduleRoot $OutputPath
        }

        $outputDir = Split-Path -Parent $resolvedOutputPath
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        Write-Host "Exporting normalized data to JSON..." -ForegroundColor Yellow
        $normalized | ConvertTo-Json -Depth 10 | Out-File -FilePath $resolvedOutputPath -Encoding UTF8
        Write-Host "Exported to: $resolvedOutputPath" -ForegroundColor Green
        Write-Host ""
    }

    # Statistics
    Write-Host "Statistics:" -ForegroundColor Cyan
    Write-Host "===========" -ForegroundColor Cyan
    Write-Host "Original records:  $($csvData.Count)" -ForegroundColor White
    Write-Host "Normalized records: $($normalized.Count)" -ForegroundColor White
    Write-Host "Template used:     $($template.Name)" -ForegroundColor White
    Write-Host ""

    Write-Host "Normalization completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
