<#
.SYNOPSIS
    Example script demonstrating parent-student relationship extraction.

.DESCRIPTION
    This script demonstrates how to process Final Site Enrollment parent CSV data
    to extract structured parent contacts, phone numbers, and student relationships.
    
    The Final Site Enrollment parent CSV format includes multiple row types:
    1. Parent demographic records (name, address, email)
    2. Additional phone number records (just phone info)
    3. Student relationship records (studentNumber populated with flags)

.PARAMETER CsvPath
    Path to the parent CSV file. Defaults to the example file.

.PARAMETER OutputDir
    Optional directory to export structured data as separate JSON files.

.EXAMPLE
    ./Example-ParentStudentRelationships.ps1
    Processes the example parents CSV file.

.EXAMPLE
    ./Example-ParentStudentRelationships.ps1 -CsvPath ./data/incoming/parents.csv
    Processes a specific parents CSV file.

.EXAMPLE
    ./Example-ParentStudentRelationships.ps1 -CsvPath ./data/incoming/parents.csv -OutputDir ./data/processed
    Processes parents data and exports to JSON files.

.NOTES
    Author: Mennotech
    Requires: PowerShell 7.0+, fsenrollment-pssync module
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = './data/examples/parents_example.csv',

    [Parameter(Mandatory = $false)]
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Parent-Student Relationships Extraction Example" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
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
    Write-Host ""

    # Import CSV data
    Write-Host "Importing parent CSV data..." -ForegroundColor Yellow
    $csvData = Import-Csv -LiteralPath $resolvedCsvPath
    Write-Host "Loaded $($csvData.Count) CSV rows" -ForegroundColor Green
    Write-Host ""

    # Process the data
    Write-Host "Processing parent-student relationships..." -ForegroundColor Yellow
    $structured = ConvertTo-ParentStudentRelationships -CsvData $csvData -Verbose
    Write-Host ""

    # Display results
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Processing Results" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "CSV Rows Processed:    $($csvData.Count)" -ForegroundColor White
    Write-Host "Contacts Extracted:    $($structured.Contacts.Count)" -ForegroundColor Green
    Write-Host "Phone Numbers:         $($structured.PhoneNumbers.Count)" -ForegroundColor Green
    Write-Host "Relationships:         $($structured.Relationships.Count)" -ForegroundColor Green
    Write-Host ""

    # Show sample contact
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Sample Contact Record" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    if ($structured.Contacts.Count -gt 0) {
        $sampleContact = $structured.Contacts[0]
        $sampleContact | Format-List
    }

    # Show phone numbers for sample contact
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Phone Numbers for Sample Contact" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    $sampleContactId = $structured.Contacts[0].id
    $samplePhones = $structured.PhoneNumbers | Where-Object { $_.contact_id -eq $sampleContactId }
    Write-Host "Contact has $($samplePhones.Count) phone number(s):" -ForegroundColor Yellow
    $samplePhones | Format-Table -AutoSize
    Write-Host ""

    # Show relationships for sample contact
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Relationships for Sample Contact" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    $sampleRelationships = $structured.Relationships | Where-Object { $_.contact_id -eq $sampleContactId }
    Write-Host "Contact has $($sampleRelationships.Count) student relationship(s):" -ForegroundColor Yellow
    $sampleRelationships | Format-Table -Property student_number, relationship_type, legal_guardian, has_custody, lives_with -AutoSize
    Write-Host ""

    # Find a contact with multiple phones
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Example: Contact with Multiple Phones" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    $contactsWithMultiplePhones = $structured.Contacts | Where-Object {
        $contactId = $_.id
        $phoneCount = ($structured.PhoneNumbers | Where-Object { $_.contact_id -eq $contactId }).Count
        $phoneCount -gt 1
    }
    
    if ($contactsWithMultiplePhones.Count -gt 0) {
        $multiPhoneContact = $contactsWithMultiplePhones[0]
        Write-Host "Contact: $($multiPhoneContact.first_name) $($multiPhoneContact.last_name)" -ForegroundColor Yellow
        $multiPhones = $structured.PhoneNumbers | Where-Object { $_.contact_id -eq $multiPhoneContact.id }
        $multiPhones | Format-Table -Property phone_type, phone_number, is_preferred_phone, is_sms -AutoSize
    } else {
        Write-Host "No contacts with multiple phone numbers found" -ForegroundColor Gray
    }
    Write-Host ""

    # Find a contact with multiple relationships
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Example: Contact with Multiple Children" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    $contactsWithMultipleRelationships = $structured.Contacts | Where-Object {
        $contactId = $_.id
        $relCount = ($structured.Relationships | Where-Object { $_.contact_id -eq $contactId }).Count
        $relCount -gt 1
    }
    
    if ($contactsWithMultipleRelationships.Count -gt 0) {
        $multiRelContact = $contactsWithMultipleRelationships[0]
        Write-Host "Contact: $($multiRelContact.first_name) $($multiRelContact.last_name)" -ForegroundColor Yellow
        $multiRels = $structured.Relationships | Where-Object { $_.contact_id -eq $multiRelContact.id }
        $multiRels | Format-Table -Property student_number, relationship_type, contact_priority_order -AutoSize
    } else {
        Write-Host "No contacts with multiple student relationships found" -ForegroundColor Gray
    }
    Write-Host ""

    # Export to JSON if requested
    if ($OutputDir) {
        $resolvedOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
            $OutputDir
        } else {
            Join-Path $moduleRoot $OutputDir
        }

        if (-not (Test-Path $resolvedOutputDir)) {
            New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
        }

        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Exporting to JSON" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan

        $contactsFile = Join-Path $resolvedOutputDir 'contacts.json'
        $phonesFile = Join-Path $resolvedOutputDir 'phone_numbers.json'
        $relationshipsFile = Join-Path $resolvedOutputDir 'relationships.json'

        $structured.Contacts | ConvertTo-Json -Depth 10 | Out-File -FilePath $contactsFile -Encoding UTF8
        Write-Host "Contacts:      $contactsFile" -ForegroundColor Green

        $structured.PhoneNumbers | ConvertTo-Json -Depth 10 | Out-File -FilePath $phonesFile -Encoding UTF8
        Write-Host "Phone Numbers: $phonesFile" -ForegroundColor Green

        $structured.Relationships | ConvertTo-Json -Depth 10 | Out-File -FilePath $relationshipsFile -Encoding UTF8
        Write-Host "Relationships: $relationshipsFile" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "✓ Successfully processed parent CSV data" -ForegroundColor Green
    Write-Host "✓ Extracted contacts with demographics" -ForegroundColor Green
    Write-Host "✓ Collected all phone numbers (including multiples)" -ForegroundColor Green
    Write-Host "✓ Built parent-student relationship records" -ForegroundColor Green
    Write-Host ""
    Write-Host "The structured data is now ready for PowerSchool API submission." -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
