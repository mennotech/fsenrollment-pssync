#Requires -Version 7.0

<#
.SYNOPSIS
    Example script demonstrating PowerSchool change detection.

.DESCRIPTION
    This script demonstrates the complete workflow for detecting changes between
    CSV data from Final Site Enrollment and PowerSchool data via API.
    
    Prerequisites:
    - PowerSchool API credentials set in environment variables:
      * PowerSchool_BaseUrl
      * PowerSchool_ClientID
      * PowerSchool_ClientSecret
    - CSV file with student data
    
.PARAMETER CsvPath
    Path to the CSV file containing student data.

.PARAMETER TemplateName
    Template name for parsing the CSV. Default: 'fs_powerschool_nonapi_report_students'

.PARAMETER OutputPath
    Path where the change report JSON file will be saved. Default: './data/pending_changes.json'

.EXAMPLE
    .\Example-ChangeDetection.ps1 -CsvPath './data/students.csv'
    
.EXAMPLE
    # Set environment variables first
    $env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
    $env:PowerSchool_ClientID = 'your-client-id'
    $env:PowerSchool_ClientSecret = 'your-secret'
    
    .\Example-ChangeDetection.ps1 -CsvPath './data/examples/fs_powerschool_nonapi_report/students_example.csv'
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath,
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateName = 'fs_powerschool_nonapi_report_students',
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = './data/pending_changes.json'
)

# Import the module
$ModulePath = Join-Path $PSScriptRoot 'fsenrollment-pssync/FSEnrollment-PSSync.psd1'
Import-Module $ModulePath -Force

Write-Host "=== PowerSchool Change Detection Example ===" -ForegroundColor Cyan
Write-Host ""

try {
    # Step 1: Connect to PowerSchool
    Write-Host "[1/4] Connecting to PowerSchool..." -ForegroundColor Yellow
    Connect-PowerSchool
    Write-Host ""
    
    # Step 2: Import CSV data
    Write-Host "[2/4] Importing CSV data from: $CsvPath" -ForegroundColor Yellow
    $csvData = Import-FSCsv -Path $CsvPath -TemplateName $TemplateName
    Write-Host "  Loaded $($csvData.Students.Count) students from CSV" -ForegroundColor Green
    Write-Host ""
    
    # Step 3: Fetch PowerSchool data
    Write-Host "[3/4] Fetching student data from PowerSchool..." -ForegroundColor Yellow
    Write-Host "  This may take a while for large datasets..." -ForegroundColor Gray
    $psStudents = Get-PowerSchoolStudent -All
    Write-Host "  Retrieved $($psStudents.Count) students from PowerSchool" -ForegroundColor Green
    Write-Host ""
    
    # Step 4: Compare and detect changes
    Write-Host "[4/4] Comparing data and detecting changes..." -ForegroundColor Yellow
    $changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents
    Write-Host ""
    
    # Display summary
    Write-Host "=== Change Detection Results ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Data Sources:" -ForegroundColor White
    Write-Host "  CSV file:        $($changes.Summary.TotalInCsv) students"
    Write-Host "  PowerSchool:     $($changes.Summary.TotalInPowerSchool) students"
    Write-Host "  Match field:     $($changes.Summary.MatchField)"
    Write-Host ""
    
    Write-Host "Changes Detected:" -ForegroundColor White
    Write-Host "  New students:       $($changes.Summary.NewCount)" -ForegroundColor Green
    Write-Host "  Updated students:   $($changes.Summary.UpdatedCount)" -ForegroundColor Cyan
    Write-Host "  Unchanged students: $($changes.Summary.UnchangedCount)" -ForegroundColor Gray
    Write-Host "  Removed students:   $($changes.Summary.RemovedCount)" -ForegroundColor Red
    Write-Host ""
    
    # Show details for new students
    if ($changes.New.Count -gt 0) {
        Write-Host "New Students (not in PowerSchool):" -ForegroundColor Green
        foreach ($new in $changes.New | Select-Object -First 10) {
            $student = $new.Student
            Write-Host "  [$($student.StudentNumber)] $($student.FirstName) $($student.LastName) - Grade $($student.GradeLevel)"
        }
        if ($changes.New.Count -gt 10) {
            Write-Host "  ... and $($changes.New.Count - 10) more" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Show details for updated students
    if ($changes.Updated.Count -gt 0) {
        Write-Host "Updated Students (changes detected):" -ForegroundColor Cyan
        foreach ($updated in $changes.Updated | Select-Object -First 5) {
            Write-Host "  [$($updated.MatchKey)]"
            foreach ($change in $updated.Changes | Select-Object -First 3) {
                Write-Host "    $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
            }
            if ($updated.Changes.Count -gt 3) {
                Write-Host "    ... and $($updated.Changes.Count - 3) more changes" -ForegroundColor Gray
            }
        }
        if ($changes.Updated.Count -gt 5) {
            Write-Host "  ... and $($changes.Updated.Count - 5) more students" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Show details for removed students
    if ($changes.Removed.Count -gt 0) {
        Write-Host "Removed Students (in PowerSchool but not in CSV):" -ForegroundColor Red
        foreach ($removed in $changes.Removed | Select-Object -First 10) {
            $student = $removed.Student
            Write-Host "  [$($student.student_number)] $($student.first_name) $($student.last_name)"
        }
        if ($changes.Removed.Count -gt 10) {
            Write-Host "  ... and $($changes.Removed.Count - 10) more" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Export changes to JSON
    Write-Host "Exporting change report..." -ForegroundColor Yellow
    
    # Ensure output directory exists
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $changesJson = $changes | ConvertTo-Json -Depth 10
    $changesJson | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "  Change report saved to: $OutputPath" -ForegroundColor Green
    Write-Host ""
    
    # Summary
    Write-Host "=== Complete ===" -ForegroundColor Cyan
    $totalChanges = $changes.Summary.NewCount + $changes.Summary.UpdatedCount + $changes.Summary.RemovedCount
    if ($totalChanges -eq 0) {
        Write-Host "No changes detected. All data is synchronized." -ForegroundColor Green
    } else {
        Write-Host "Detected $totalChanges total changes that may require attention." -ForegroundColor Yellow
        Write-Host "Please review the change report at: $OutputPath" -ForegroundColor White
    }
    
    exit 0
}
catch {
    Write-Error "An error occurred: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
