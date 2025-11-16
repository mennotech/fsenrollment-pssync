#Requires -Version 7.0

<#
.SYNOPSIS
    Complete PowerSchool change detection workflow with HTML report generation.

.DESCRIPTION
    This script runs the complete change detection workflow:
    1. Compares incoming CSV data with PowerSchool
    2. Generates change detection JSON files
    3. Creates a comprehensive HTML report
    
.PARAMETER StudentsCSV
    Path to the students CSV file. Default: './data/incoming/students.csv'

.PARAMETER ParentsCSV
    Path to the parents/contacts CSV file. Default: './data/incoming/parents.csv'

.PARAMETER OutputDirectory
    Directory where output files will be saved. Default: './data'

.PARAMETER OpenReport
    Switch to automatically open the HTML report when complete.

.EXAMPLE
    .\Run-CompleteChangeDetection.ps1
    
.EXAMPLE
    .\Run-CompleteChangeDetection.ps1 -StudentsCSV ".\data\incoming\students.csv" -ParentsCSV ".\data\incoming\parents.csv" -OutputDirectory ".\data" -OpenReport
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$StudentsCSV = "./data/incoming/students.csv",
    
    [Parameter(Mandatory = $false)]
    [string]$ParentsCSV = "./data/incoming/parents.csv",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = "./data",
    
    [Parameter(Mandatory = $false)]
    [switch]$OpenReport
)

$ErrorActionPreference = "Stop"

Write-Host "=== PowerSchool Complete Change Detection Workflow ===" -ForegroundColor Cyan
Write-Host ""

try {
    # Check if CSV files exist
    Write-Host "[1/5] Validating input files..." -ForegroundColor Yellow
    if (-not (Test-Path $StudentsCSV)) {
        throw "Students CSV file not found: $StudentsCSV"
    }
    if (-not (Test-Path $ParentsCSV)) {
        throw "Parents CSV file not found: $ParentsCSV"
    }
    Write-Host "  ✓ Students CSV: $StudentsCSV" -ForegroundColor Green
    Write-Host "  ✓ Parents CSV: $ParentsCSV" -ForegroundColor Green
    Write-Host ""
    
    # Import the module and test PowerSchool connection
    Write-Host "[2/5] Connecting to PowerSchool..." -ForegroundColor Yellow
    $ModulePath = Join-Path $PSScriptRoot '../fsenrollment-pssync/FSEnrollment-PSSync.psd1'
    if (-not (Test-Path $ModulePath)) {
        throw "Module not found: $ModulePath"
    }
    Import-Module $ModulePath -Force
    Connect-PowerSchool
    Write-Host "  ✓ Connected to PowerSchool" -ForegroundColor Green
    Write-Host ""
    
    # Define output file paths with organized structure and date-first naming
    $timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
    $studentChangesPath = Join-Path $OutputDirectory "pending/$timestamp-student-changes.json"
    $contactChangesPath = Join-Path $OutputDirectory "pending/$timestamp-contact-changes.json"
    $htmlReportPath = Join-Path $OutputDirectory "reports/$timestamp-change-detection-report.html"
    
    # Ensure output directories exist
    $pendingDir = Join-Path $OutputDirectory "pending"
    $reportsDir = Join-Path $OutputDirectory "reports"
    if (-not (Test-Path $pendingDir)) {
        New-Item -ItemType Directory -Path $pendingDir -Force | Out-Null
    }
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    # Run student change detection
    Write-Host "[3/5] Running student change detection..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "Example-ChangeDetection.ps1") -CsvPath $StudentsCSV -OutputPath $studentChangesPath
    Write-Host "  ✓ Student changes exported to: $studentChangesPath" -ForegroundColor Green
    Write-Host ""
    
    # Run contact change detection
    Write-Host "[4/5] Running contact change detection..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "Example-ContactChangeDetection.ps1") -CsvPath $ParentsCSV -OutputPath $contactChangesPath
    Write-Host "  ✓ Contact changes exported to: $contactChangesPath" -ForegroundColor Green
    Write-Host ""
    
    # Generate HTML report
    Write-Host "[5/5] Generating HTML report..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "Generate-ChangeDetectionHtmlReport.ps1") -StudentChangesPath $studentChangesPath -ContactChangesPath $contactChangesPath -OutputPath $htmlReportPath
    Write-Host "  ✓ HTML report generated: $htmlReportPath" -ForegroundColor Green
    Write-Host ""
    
    # Summary
    Write-Host "=== Workflow Complete ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Output files generated:" -ForegroundColor White
    Write-Host "  • Student changes (JSON): $studentChangesPath" -ForegroundColor Gray
    Write-Host "  • Contact changes (JSON): $contactChangesPath" -ForegroundColor Gray
    Write-Host "  • Combined HTML report:   $htmlReportPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Organized in data directory structure:" -ForegroundColor White
    Write-Host "  • data/pending/   - Change detection JSON files" -ForegroundColor Gray
    Write-Host "  • data/reports/   - HTML reports" -ForegroundColor Gray
    Write-Host "  • data/processed/ - Processed files (future use)" -ForegroundColor Gray
    Write-Host "  • data/archive/   - Archived files (future use)" -ForegroundColor Gray
    Write-Host ""
    
    # Load change summaries for final report
    $studentData = Get-Content -Path $studentChangesPath -Raw | ConvertFrom-Json
    $contactData = Get-Content -Path $contactChangesPath -Raw | ConvertFrom-Json
    
    Write-Host "Change Summary:" -ForegroundColor White
    Write-Host "  Students - New: $($studentData.Summary.NewCount), Updated: $($studentData.Summary.UpdatedCount), Unchanged: $($studentData.Summary.UnchangedCount)" -ForegroundColor Gray
    Write-Host "  Contacts - New: $($contactData.New.Count), Updated: $($contactData.Updated.Count), Unchanged: $($contactData.Unchanged.Count)" -ForegroundColor Gray
    Write-Host ""
    
    $totalChanges = $studentData.Summary.NewCount + $studentData.Summary.UpdatedCount + $contactData.New.Count + $contactData.Updated.Count
    if ($totalChanges -eq 0) {
        Write-Host "No changes detected. All data appears to be synchronized." -ForegroundColor Green
    } else {
        Write-Host "Total changes detected: $totalChanges" -ForegroundColor Yellow
        Write-Host "Please review the HTML report for detailed analysis." -ForegroundColor White
    }
    
    if ($OpenReport) {
        Write-Host ""
        Write-Host "Opening HTML report..." -ForegroundColor Cyan
        Start-Process $htmlReportPath
    }
    
    exit 0
}
catch {
    Write-Error "An error occurred during the change detection workflow: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}