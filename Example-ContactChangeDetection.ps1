#Requires -Version 7.0

<#
.SYNOPSIS
    Example script demonstrating PowerSchool contact change detection using PowerQuery.

.DESCRIPTION
    This script demonstrates the workflow for detecting changes between CSV contact data
    and PowerSchool person data using the com.fsenrollment.dats.person PowerQuery.
    
    Prerequisites:
    - PowerSchool API credentials set in environment variables:
      * PowerSchool_BaseUrl
      * PowerSchool_ClientID
      * PowerSchool_ClientSecret
    - PowerSchool API plugin installed with com.fsenrollment.dats.person PowerQuery
    - CSV file with contact data
    
.PARAMETER CsvPath
    Path to the CSV file containing contact data.

.PARAMETER TemplateName
    Template name for parsing the CSV. Default: 'fs_powerschool_contacts'

.PARAMETER OutputPath
    Path where the contact change report JSON file will be saved. 
    Default: './data/pending_contact_changes.json'

.EXAMPLE
    .\Example-ContactChangeDetection.ps1 -CsvPath './data/contacts.csv'
    
.EXAMPLE
    # Set environment variables first
    $env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
    $env:PowerSchool_ClientID = 'your-client-id'
    $env:PowerSchool_ClientSecret = 'your-secret'
    
    .\Example-ContactChangeDetection.ps1 -CsvPath './data/contacts.csv' -Verbose

.NOTES
    This example script only compares PSContact fields (FirstName, MiddleName, LastName, 
    Gender, Employer). Email addresses, phone numbers, and addresses are not compared
    at this stage.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath,
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateName = 'fs_powerschool_contacts',
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = './data/pending_contact_changes.json'
)

# Import the module
Import-Module (Join-Path $PSScriptRoot 'fsenrollment-pssync/FSEnrollment-PSSync.psd1') -Force

try {
    Write-Host "=== PowerSchool Contact Change Detection ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Connect to PowerSchool
    Write-Host "[1/4] Connecting to PowerSchool..." -ForegroundColor Yellow
    Connect-PowerSchool
    Write-Host "  ✓ Connected successfully" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: Import CSV data
    Write-Host "[2/4] Importing contact data from CSV..." -ForegroundColor Yellow
    Write-Host "  CSV Path: $CsvPath" -ForegroundColor Gray
    Write-Host "  Template: $TemplateName" -ForegroundColor Gray
    
    $csvData = Import-FSCsv -Path $CsvPath -TemplateName $TemplateName -Verbose:$VerbosePreference
    
    Write-Host "  ✓ Imported $($csvData.Contacts.Count) contacts from CSV" -ForegroundColor Green
    Write-Host ""
    
    # Step 3: Fetch PowerSchool person data using PowerQuery
    Write-Host "[3/4] Fetching person data from PowerSchool..." -ForegroundColor Yellow
    Write-Host "  PowerQuery: com.fsenrollment.dats.person" -ForegroundColor Gray
    
    $personData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords -Verbose:$VerbosePreference
    
    Write-Host "  ✓ Retrieved $($personData.RecordCount) person records from PowerSchool" -ForegroundColor Green
    Write-Host ""
    
    # Step 4: Compare and detect changes
    Write-Host "[4/4] Comparing contact data..." -ForegroundColor Yellow
    Write-Host "  Comparing: FirstName, MiddleName, LastName, Gender, Employer" -ForegroundColor Gray
    
    $changes = Compare-PSContact -CsvData $csvData `
        -PowerSchoolData $personData.Records `
        -Verbose:$VerbosePreference
    
    Write-Host "  ✓ Comparison complete" -ForegroundColor Green
    Write-Host ""
    
    # Display results
    Write-Host "=== Change Detection Results ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Total in CSV:          $($changes.Summary.TotalInCsv)"
    Write-Host "  Total in PowerSchool:  $($changes.Summary.TotalInPowerSchool)"
    Write-Host "  New contacts:          $($changes.Summary.NewCount)" -ForegroundColor Green
    Write-Host "  Updated contacts:      $($changes.Summary.UpdatedCount)" -ForegroundColor Cyan
    Write-Host "  Unchanged contacts:    $($changes.Summary.UnchangedCount)" -ForegroundColor Gray
    Write-Host ""
    
    # Display new contacts
    if ($changes.New.Count -gt 0) {
        Write-Host "New Contacts:" -ForegroundColor Green
        foreach ($new in $changes.New | Select-Object -First 10) {
            $contact = $new.Contact
            Write-Host "  ID $($contact.ContactID): $($contact.FirstName) $($contact.LastName)"
        }
        if ($changes.New.Count -gt 10) {
            Write-Host "  ... and $($changes.New.Count - 10) more" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Display updated contacts
    if ($changes.Updated.Count -gt 0) {
        Write-Host "Updated Contacts:" -ForegroundColor Cyan
        foreach ($updated in $changes.Updated | Select-Object -First 10) {
            Write-Host "  Contact ID: $($updated.MatchKey)"
            foreach ($change in $updated.Changes) {
                $oldVal = if ($change.OldValue) { "'$($change.OldValue)'" } else { "(empty)" }
                $newVal = if ($change.NewValue) { "'$($change.NewValue)'" } else { "(empty)" }
                Write-Host "    $($change.Field): $oldVal -> $newVal"
            }
        }
        if ($changes.Updated.Count -gt 10) {
            Write-Host "  ... and $($changes.Updated.Count - 10) more" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Export changes to JSON for review/approval
    Write-Host "Exporting changes to JSON..." -ForegroundColor Yellow
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    $changesJson = $changes | ConvertTo-Json -Depth 10
    $changesJson | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "  ✓ Changes exported to: $OutputPath" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "=== Next Steps ===" -ForegroundColor Cyan
    Write-Host "1. Review the changes in: $OutputPath"
    Write-Host "2. Validate the changes are expected"
    Write-Host "3. Apply approved changes to PowerSchool (functionality to be implemented)"
    Write-Host ""
    
    Write-Host "Done!" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
