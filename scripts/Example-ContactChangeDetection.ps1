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
    Template name for parsing the CSV. Default: 'fs_powerschool_nonapi_report_parents'

.PARAMETER OutputPath
    Path where the contact change report JSON file will be saved. 
    Default: './data/pending/[date]-contact-changes.json'

.EXAMPLE
    .\Example-ContactChangeDetection.ps1 -CsvPath './data/contacts.csv'
    
.EXAMPLE
    # Set environment variables first
    $env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
    $env:PowerSchool_ClientID = 'your-client-id'
    $env:PowerSchool_ClientSecret = 'your-secret'
    
    .\Example-ContactChangeDetection.ps1 -CsvPath './data/contacts.csv' -Verbose

.NOTES
    This example script compares PSContact fields (FirstName, MiddleName, LastName, 
    Gender, Employer) as well as email addresses, phone numbers, addresses, and 
    student-contact relationships when available in the CSV data.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath,
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateName = 'fs_powerschool_nonapi_report_parents',
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./data/pending/$(Get-Date -Format 'yyyy-MM-dd-HHmm')-contact-changes.json"
)

# Import the module
Import-Module (Join-Path $PSScriptRoot '../fsenrollment-pssync/FSEnrollment-PSSync.psd1') -Force

try {
    Write-Host "=== PowerSchool Contact Change Detection ===" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Connect to PowerSchool
    Write-Host "[1/8] Connecting to PowerSchool..." -ForegroundColor Yellow
    Connect-PowerSchool
    Write-Host "  ✓ Connected successfully" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: Import CSV data
    Write-Host "[2/8] Importing contact data from CSV..." -ForegroundColor Yellow
    Write-Host "  CSV Path: $CsvPath" -ForegroundColor Gray
    Write-Host "  Template: $TemplateName" -ForegroundColor Gray
    
    # Load template configuration for comparison settings
    $configRoot = Join-Path $PSScriptRoot '../config'
    $templatePath = Join-Path $configRoot "templates/$TemplateName.psd1"
    
    if (-not (Test-Path $templatePath)) {
        throw "Template configuration not found: $templatePath"
    }
    
    $templateConfig = Import-PowerShellDataFile -Path $templatePath
    
    $csvData = Import-FSCsv -Path $CsvPath -TemplateName $TemplateName -Verbose:$VerbosePreference
    
    Write-Host "  ✓ Imported $($csvData.Contacts.Count) contacts from CSV" -ForegroundColor Green
    if ($csvData.EmailAddresses.Count -gt 0) {
        Write-Host "  ✓ Found $($csvData.EmailAddresses.Count) email addresses" -ForegroundColor Green
    }
    if ($csvData.PhoneNumbers.Count -gt 0) {
        Write-Host "  ✓ Found $($csvData.PhoneNumbers.Count) phone numbers" -ForegroundColor Green
    }
    if ($csvData.Addresses.Count -gt 0) {
        Write-Host "  ✓ Found $($csvData.Addresses.Count) addresses" -ForegroundColor Green
    }
    if ($csvData.Relationships.Count -gt 0) {
        Write-Host "  ✓ Found $($csvData.Relationships.Count) relationships" -ForegroundColor Green
    }
    Write-Host ""
    
    # Step 3: Fetch PowerSchool person data using PowerQueries
    Write-Host "[3/8] Fetching person data from PowerSchool..." -ForegroundColor Yellow
    Write-Host "  PowerQuery: com.fsenrollment.dats.person" -ForegroundColor Gray
    
    $personData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person' -AllRecords -Verbose:$VerbosePreference
    
    Write-Host "  ✓ Retrieved $($personData.RecordCount) person records from PowerSchool" -ForegroundColor Green
    Write-Host ""
    
    # Step 4: Fetch email data if CSV has emails
    $emailData = $null
    if ($csvData.EmailAddresses.Count -gt 0) {
        Write-Host "[4/8] Fetching email data from PowerSchool..." -ForegroundColor Yellow
        Write-Host "  PowerQuery: com.fsenrollment.dats.person.email" -ForegroundColor Gray
        
        $emailData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.email' -AllRecords -Verbose:$VerbosePreference
        
        Write-Host "  ✓ Retrieved $($emailData.RecordCount) email records from PowerSchool" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "[4/8] Skipping email data (no emails in CSV)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Step 5: Fetch phone data if CSV has phones
    $phoneData = $null
    if ($csvData.PhoneNumbers.Count -gt 0) {
        Write-Host "[5/8] Fetching phone data from PowerSchool..." -ForegroundColor Yellow
        Write-Host "  PowerQuery: com.fsenrollment.dats.person.phone" -ForegroundColor Gray
        
        $phoneData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.phone' -AllRecords -Verbose:$VerbosePreference
        
        Write-Host "  ✓ Retrieved $($phoneData.RecordCount) phone records from PowerSchool" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "[5/8] Skipping phone data (no phones in CSV)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Step 6: Fetch address data if CSV has addresses
    $addressData = $null
    if ($csvData.Addresses.Count -gt 0) {
        Write-Host "[6/8] Fetching address data from PowerSchool..." -ForegroundColor Yellow
        Write-Host "  PowerQuery: com.fsenrollment.dats.person.address" -ForegroundColor Gray
        
        $addressData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.address' -AllRecords -Verbose:$VerbosePreference
        
        Write-Host "  ✓ Retrieved $($addressData.RecordCount) address records from PowerSchool" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "[6/8] Skipping address data (no addresses in CSV)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Step 7: Fetch relationship data if CSV has relationships
    $relationshipData = $null
    if ($csvData.Relationships.Count -gt 0) {
        Write-Host "[7/8] Fetching relationship data from PowerSchool..." -ForegroundColor Yellow
        Write-Host "  PowerQuery: com.fsenrollment.dats.person.relationship" -ForegroundColor Gray
        
        $relationshipData = Invoke-PowerQuery -PowerQueryName 'com.fsenrollment.dats.person.relationship' -AllRecords -Verbose:$VerbosePreference
        
        Write-Host "  ✓ Retrieved $($relationshipData.RecordCount) relationship records from PowerSchool" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "[7/8] Skipping relationship data (no relationships in CSV)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Step 8: Compare and detect changes
    Write-Host "[8/8] Comparing contact data..." -ForegroundColor Yellow
    $fieldsToCheck = $templateConfig.EntityTypeMap.Contact.CheckForChanges -join ', '
    Write-Host "  Comparing: $fieldsToCheck" -ForegroundColor Gray
    Write-Host "  Key Field: $($templateConfig.KeyField) -> $($templateConfig.PowerSchoolKeyField)" -ForegroundColor Gray
    
    # Build comparison parameters
    $compareParams = @{
        CsvData = $csvData
        PowerSchoolData = $personData.Records
        TemplateConfig = $templateConfig
        Verbose = $VerbosePreference
    }
    
    # Add optional PowerQuery data if available
    if ($emailData) {
        $compareParams['PowerSchoolEmailData'] = $emailData.Records
        Write-Host "  Including email address comparison" -ForegroundColor Gray
    }
    if ($phoneData) {
        $compareParams['PowerSchoolPhoneData'] = $phoneData.Records
        Write-Host "  Including phone number comparison" -ForegroundColor Gray
    }
    if ($addressData) {
        $compareParams['PowerSchoolAddressData'] = $addressData.Records
        Write-Host "  Including address comparison" -ForegroundColor Gray
    }
    if ($relationshipData) {
        $compareParams['PowerSchoolRelationshipData'] = $relationshipData.Records
        Write-Host "  Including relationship comparison" -ForegroundColor Gray
    }
    
    $changes = Compare-PSContact @compareParams
    
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
            Write-Host "  ID $($new.MatchKey): $($contact.FirstName) $($contact.LastName)"
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
            
            # Display field changes
            if ($updated.Changes -and $updated.Changes.Count -gt 0) {
                foreach ($change in $updated.Changes) {
                    $oldVal = if ($change.OldValue) { "'$($change.OldValue)'" } else { "(empty)" }
                    $newVal = if ($change.NewValue) { "'$($change.NewValue)'" } else { "(empty)" }
                    Write-Host "    $($change.Field): $oldVal -> $newVal"
                }
            }
            
            # Display email changes
            if ($updated.EmailChanges) {
                if ($updated.EmailChanges.Added.Count -gt 0) {
                    Write-Host "    Emails Added: $($updated.EmailChanges.Added.Count)" -ForegroundColor Green
                    foreach ($email in $updated.EmailChanges.Added | Select-Object -First 3) {
                        Write-Host "      + $($email.EmailAddress)"
                    }
                }
                if ($updated.EmailChanges.Modified.Count -gt 0) {
                    Write-Host "    Emails Modified: $($updated.EmailChanges.Modified.Count)" -ForegroundColor Yellow
                }
                if ($updated.EmailChanges.Removed.Count -gt 0) {
                    Write-Host "    Emails Removed: $($updated.EmailChanges.Removed.Count)" -ForegroundColor Red
                }
            }
            
            # Display phone changes
            if ($updated.PhoneChanges) {
                if ($updated.PhoneChanges.Added.Count -gt 0) {
                    Write-Host "    Phones Added: $($updated.PhoneChanges.Added.Count)" -ForegroundColor Green
                    foreach ($phone in $updated.PhoneChanges.Added | Select-Object -First 3) {
                        Write-Host "      + $($phone.DisplayNumber)"
                    }
                }
                if ($updated.PhoneChanges.Modified.Count -gt 0) {
                    Write-Host "    Phones Modified: $($updated.PhoneChanges.Modified.Count)" -ForegroundColor Yellow
                }
                if ($updated.PhoneChanges.Removed.Count -gt 0) {
                    Write-Host "    Phones Removed: $($updated.PhoneChanges.Removed.Count)" -ForegroundColor Red
                }
            }
            
            # Display address changes
            if ($updated.AddressChanges) {
                if ($updated.AddressChanges.Added.Count -gt 0) {
                    Write-Host "    Addresses Added: $($updated.AddressChanges.Added.Count)" -ForegroundColor Green
                    foreach ($addr in $updated.AddressChanges.Added | Select-Object -First 2) {
                        Write-Host "      + $($addr.DisplayAddress)"
                    }
                }
                if ($updated.AddressChanges.Modified.Count -gt 0) {
                    Write-Host "    Addresses Modified: $($updated.AddressChanges.Modified.Count)" -ForegroundColor Yellow
                }
                if ($updated.AddressChanges.Removed.Count -gt 0) {
                    Write-Host "    Addresses Removed: $($updated.AddressChanges.Removed.Count)" -ForegroundColor Red
                }
            }
            
            # Display relationship changes
            if ($updated.RelationshipChanges) {
                if ($updated.RelationshipChanges.Added.Count -gt 0) {
                    Write-Host "    Relationships Added: $($updated.RelationshipChanges.Added.Count)" -ForegroundColor Green
                    foreach ($rel in $updated.RelationshipChanges.Added | Select-Object -First 3) {
                        $relInfo = $rel.Relationship
                        Write-Host "      + Student $($rel.StudentNumber): $($relInfo.RelationshipType)"
                    }
                }
                if ($updated.RelationshipChanges.Modified.Count -gt 0) {
                    Write-Host "    Relationships Modified: $($updated.RelationshipChanges.Modified.Count)" -ForegroundColor Yellow
                    foreach ($rel in $updated.RelationshipChanges.Modified | Select-Object -First 2) {
                        Write-Host "      ~ Student $($rel.StudentNumber): $($rel.Changes.Count) changes"
                    }
                }
                if ($updated.RelationshipChanges.Removed.Count -gt 0) {
                    Write-Host "    Relationships Removed: $($updated.RelationshipChanges.Removed.Count)" -ForegroundColor Red
                }
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
