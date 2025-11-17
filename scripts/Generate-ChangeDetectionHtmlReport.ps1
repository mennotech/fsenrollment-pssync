#Requires -Version 7.0

<#
.SYNOPSIS
    Generates an HTML report from PowerSchool change detection results.

.DESCRIPTION
    This script combines student and contact change detection JSON files into
    a comprehensive HTML report with detailed analysis and visualizations.

.PARAMETER StudentChangesPath
    Path to the student changes JSON file.

.PARAMETER ContactChangesPath
    Path to the contact changes JSON file.

.PARAMETER OutputPath
    Path where the HTML report will be saved.

.EXAMPLE
    .\Generate-ChangeDetectionHtmlReport.ps1 -StudentChangesPath ".\data\pending\2025-11-15-1200-student-changes.json" -ContactChangesPath ".\data\pending\2025-11-15-1200-contact-changes.json" -OutputPath ".\data\reports\2025-11-15-1200-change-detection-report.html"
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$StudentChangesPath,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ContactChangesPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$OpenReport
)

Write-Host "=== PowerSchool Change Detection HTML Report Generator ===" -ForegroundColor Cyan
Write-Host ""

try {
    # Load the JSON data
    Write-Host "Loading change detection data..." -ForegroundColor Yellow
    $studentChanges = Get-Content -Path $StudentChangesPath -Raw | ConvertFrom-Json
    $contactChanges = Get-Content -Path $ContactChangesPath -Raw | ConvertFrom-Json

    Write-Host "  Student changes loaded: $($studentChanges.New.Count) new, $($studentChanges.Updated.Count) updated" -ForegroundColor Green
    Write-Host "  Contact changes loaded: $($contactChanges.New.Count) new, $($contactChanges.Updated.Count) updated" -ForegroundColor Green
    Write-Host ""
    
    # Generate timestamp
    $reportDate = Get-Date -Format "MMMM dd, yyyy 'at' hh:mm tt"
    $reportTimestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
    
    # Ensure output directory exists
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        Write-Host "Creating output directory: $outputDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Create HTML content
    Write-Host "Generating HTML report..." -ForegroundColor Yellow

    # Helper: encode HTML
    function Encode-Html([string]$s) {
        if ($null -eq $s) { return '' }
        return [System.Web.HttpUtility]::HtmlEncode([string]$s)
    }

    # Helper: produce a small CSS + JS payload and modular HTML sections
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PowerSchool Change Detection Report</title>
    <style>
        :root {
            --primary-color: #2563eb;
            --success-color: #059669;
            --warning-color: #d97706;
            --danger-color: #dc2626;
            --gray-50: #f9fafb;
            --gray-100: #f3f4f6;
            --gray-200: #e5e7eb;
            --gray-300: #d1d5db;
            --gray-600: #4b5563;
            --gray-700: #374151;
            --gray-900: #111827;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: var(--gray-700);
            background-color: var(--gray-50);
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        .header {
            text-align: center;
            margin-bottom: 2rem;
            padding: 2rem;
            background: linear-gradient(135deg, var(--primary-color), #1e40af);
            color: white;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }
        
        .header .subtitle {
            font-size: 1.1rem;
            opacity: 0.9;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .card {
            background: white;
            border-radius: 10px;
            padding: 1.5rem;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            border: 1px solid var(--gray-200);
        }
        
        .card-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 1rem;
        }
        
        .card-title {
            font-size: 1.1rem;
            font-weight: 600;
            color: var(--gray-900);
        }
        
        .card-icon {
            width: 2rem;
            height: 2rem;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            color: white;
        }
        
        .card-icon.new { background-color: var(--success-color); }
        .card-icon.updated { background-color: var(--warning-color); }
        .card-icon.unchanged { background-color: var(--gray-600); }
        .card-icon.total { background-color: var(--primary-color); }
        
        .card-value {
            font-size: 2rem;
            font-weight: 700;
            color: var(--gray-900);
            margin-bottom: 0.5rem;
        }
        
        .card-description {
            color: var(--gray-600);
            font-size: 0.9rem;
        }
        
        .section {
            margin-bottom: 2rem;
        }
        
        .section-title {
            font-size: 1.5rem;
            font-weight: 600;
            color: var(--gray-900);
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid var(--primary-color);
        }
        
        .data-table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            margin-bottom: 1rem;
        }
        
        .data-table th {
            background-color: var(--gray-100);
            padding: 1rem;
            text-align: left;
            font-weight: 600;
            color: var(--gray-900);
            border-bottom: 1px solid var(--gray-200);
        }
        
        .data-table td {
            padding: 1rem;
            border-bottom: 1px solid var(--gray-200);
            vertical-align: top;
        }
        
        .data-table tr:last-child td {
            border-bottom: none;
        }
        
        .data-table tr:hover {
            background-color: var(--gray-50);
        }
        
        .change-type {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
            font-size: 0.8rem;
            font-weight: 500;
        }
        
        .change-type.added { background-color: #dcfce7; color: var(--success-color); }
        .change-type.modified { background-color: #fef3c7; color: var(--warning-color); }
        .change-type.removed { background-color: #fee2e2; color: var(--danger-color); }
        
        .field-change {
            margin-bottom: 0.5rem;
        }
        
        .field-name {
            font-weight: 600;
            color: var(--gray-900);
        }
        
        .old-value {
            color: var(--danger-color);
            text-decoration: line-through;
        }
        
        .new-value {
            color: var(--success-color);
            font-weight: 500;
        }
        
        .arrow {
            color: var(--gray-600);
            margin: 0 0.5rem;
        }
        
        .collapsible {
            cursor: pointer;
            user-select: none;
        }
        
        .collapsible:hover {
            background-color: var(--gray-50);
        }
        
        .collapsible-content {
            display: none;
        }
        
        .collapsible.expanded + .collapsible-content {
            display: table-row;
        }
        
        .expand-indicator {
            margin-right: 0.5rem;
            transition: transform 0.2s;
            display: inline-block;
        }
        
        .collapsible.expanded .expand-indicator {
            transform: rotate(90deg);
        }
        
        .metadata {
            background: white;
            border-radius: 10px;
            padding: 1.5rem;
            margin-top: 2rem;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .metadata h3 {
            margin-bottom: 1rem;
            color: var(--gray-900);
        }
        
        .metadata-grid {
            display: grid;
            grid-template-columns: auto 1fr;
            gap: 0.5rem 1rem;
        }
        
        .metadata-label {
            font-weight: 600;
            color: var(--gray-600);
        }
        
        .metadata-value {
            color: var(--gray-900);
        }
        
        .contact-group .group-header {
            transition: background-color 0.2s;
        }
        
        .contact-group .group-header:hover {
            background-color: var(--gray-200) !important;
        }
        
        .contact-group .group-header.expanded {
            background-color: var(--primary-color) !important;
            color: white;
        }
        
        .contact-group .group-header.expanded:hover {
            background-color: var(--primary-hover) !important;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 1rem;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .summary-cards {
                grid-template-columns: 1fr;
            }
            
            .data-table {
                font-size: 0.9rem;
            }
            
            .data-table th,
            .data-table td {
                padding: 0.75rem;
            }
        }
    </style>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // Lightweight handlers: toggle collapsible rows
            document.querySelectorAll('.collapsible').forEach(row => {
                row.addEventListener('click', function() { this.classList.toggle('expanded'); });
            });
        });

        function showAllContactsInGroup(button, changeType) {
            const hidden = document.querySelector('.hidden-contacts-' + changeType);
            const showRow = button.closest('.show-all-row');
            if (hidden) { hidden.style.display = 'table-row-group'; }
            if (showRow) { showRow.style.display = 'none'; }
        }
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>PowerSchool Change Detection Report</h1>
            <p class="subtitle">Generated on $reportDate</p>
        </div>
        
        <div class="summary-cards">
            <div class="card">
                <div class="card-header">
                    <div class="card-title">New Students</div>
                    <div class="card-icon new">+</div>
                </div>
                <div class="card-value">$($studentChanges.Summary.NewCount)</div>
                <div class="card-description">Students not found in PowerSchool</div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <div class="card-title">Updated Students</div>
                    <div class="card-icon updated">~</div>
                </div>
                <div class="card-value">$($studentChanges.Summary.UpdatedCount)</div>
                <div class="card-description">Students with data changes</div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <div class="card-title">New Contacts</div>
                    <div class="card-icon new">+</div>
                </div>
                <div class="card-value">$($contactChanges.New.Count)</div>
                <div class="card-description">Contacts not found in PowerSchool</div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <div class="card-title">Updated Contacts</div>
                    <div class="card-icon updated">~</div>
                </div>
                <div class="card-value">$($contactChanges.Updated.Count)</div>
                <div class="card-description">Contacts with data changes</div>
            </div>
        </div>
"@

    # Add New Students section
    if ($studentChanges.New.Count -gt 0) {
        $html += @"
        
        <div class="section">
            <h2 class="section-title">New Students ($($studentChanges.New.Count))</h2>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Student Number</th>
                        <th>Name</th>
                        <th>Grade</th>
                        <th>School ID</th>
                        <th>Phone</th>
                    </tr>
                </thead>
                <tbody>
"@
        foreach ($newStudent in $studentChanges.New | Select-Object -First 50) {
            $student = $newStudent.Student
            $html += @"
                    <tr>
                        <td>$($student.StudentNumber)</td>
                        <td>$($student.FirstName) $($student.LastName)</td>
                        <td>$($student.GradeLevel)</td>
                        <td>$($student.SchoolID)</td>
                        <td>$($student.HomePhone)</td>
                    </tr>
"@
        }
        if ($studentChanges.New.Count -gt 50) {
            $html += @"
                    <tr>
                        <td colspan="5" style="text-align: center; font-style: italic; color: var(--gray-600);">
                            ... and $($studentChanges.New.Count - 50) more students
                        </td>
                    </tr>
"@
        }
        $html += @"
                </tbody>
            </table>
        </div>
"@
    }

    # Add Updated Students section
    if ($studentChanges.Updated.Count -gt 0) {
        $html += @"
        
        <div class="section">
            <h2 class="section-title">Updated Students ($($studentChanges.Updated.Count))</h2>
            <div style="margin-bottom: 1rem;">
                <button id="expandAllStudentsBtn" style="margin-right: 0.5rem; padding: 0.5rem 1rem; border: none; background: var(--primary-color); color: white; border-radius: 4px; cursor: pointer;">Expand All</button>
                <button id="collapseAllStudentsBtn" style="padding: 0.5rem 1rem; border: none; background: var(--gray-600); color: white; border-radius: 4px; cursor: pointer;">Collapse All</button>
            </div>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Student</th>
                        <th>Changes</th>
                    </tr>
                </thead>
                <tbody>
"@
        foreach ($updatedStudent in $studentChanges.Updated | Select-Object -First 25) {
            $changeCount = $updatedStudent.Changes.Count
            $html += @"
                    <tr class="collapsible">
                        <td>
                            <span class="expand-indicator">▶</span>
                            <strong>[$($updatedStudent.MatchKey)]</strong>
                        </td>
                        <td>$changeCount field$(if ($changeCount -ne 1) { 's' }) changed</td>
                    </tr>
                    <tr class="collapsible-content">
                        <td colspan="2" style="background-color: var(--gray-50);">
"@
            foreach ($change in $updatedStudent.Changes) {
                $html += @"
                            <div class="field-change">
                                <span class="field-name">$($change.Field):</span>
                                <span class="old-value">$([System.Web.HttpUtility]::HtmlEncode($change.OldValue))</span>
                                <span class="arrow">→</span>
                                <span class="new-value">$([System.Web.HttpUtility]::HtmlEncode($change.NewValue))</span>
                            </div>
"@
            }
            $html += @"
                        </td>
                    </tr>
"@
        }
        if ($studentChanges.Updated.Count -gt 25) {
            $html += @"
                    <tr>
                        <td colspan="2" style="text-align: center; font-style: italic; color: var(--gray-600);">
                            ... and $($studentChanges.Updated.Count - 25) more students
                        </td>
                    </tr>
"@
        }
        $html += @"
                </tbody>
            </table>
        </div>
"@
    }

    # Add New Contacts section
    if ($contactChanges.New.Count -gt 0) {
        $html += @"
        
        <div class="section">
            <h2 class="section-title">New Contacts ($($contactChanges.New.Count))</h2>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Final Site Contact ID</th>
                        <th>PowerSchool Contact ID</th>
                        <th>Name</th>
                        <th>Employer</th>
                    </tr>
                </thead>
                <tbody>
"@
        foreach ($newContact in $contactChanges.New | Select-Object -First 50) {
            $contact = $newContact.Contact
            $name = @($contact.FirstName, $contact.MiddleName, $contact.LastName) | Where-Object { $_ } | Join-String -Separator ' '
            $html += @"
                    <tr>
                        <td style="font-family: monospace; font-size: 0.85rem;">$($contact.ContactIdentifier)</td>
                        <td style="font-family: monospace; font-size: 0.85rem; color: var(--gray-600); font-style: italic;">Not yet assigned</td>
                        <td><strong>$name</strong></td>
                        <td>$($contact.Employer)</td>
                    </tr>
"@
        }
        if ($contactChanges.New.Count -gt 50) {
            $html += @"
                    <tr>
                        <td colspan="4" style="text-align: center; font-style: italic; color: var(--gray-600);">
                            ... and $($contactChanges.New.Count - 50) more contacts
                        </td>
                    </tr>
"@
        }
        $html += @"
                </tbody>
            </table>
        </div>
"@
    }

    # Add Updated Contacts section with grouping by change type (defensive checks)
    if ($contactChanges.Updated.Count -gt 0) {
        # Defensive: normalize property shape
        $updated = $contactChanges.Updated

        function HasChanges($item, $prop) {
            if (-not $item.PSObject.Properties.Name -contains $prop) { return $false }
            $c = $item.$prop
            if ($null -eq $c) { return $false }
            return ($c.Added.Count -gt 0) -or ($c.Modified.Count -gt 0) -or ($c.Removed.Count -gt 0)
        }

        $emailContacts = $updated | Where-Object { HasChanges $_ 'EmailChanges' }
        $phoneContacts = $updated | Where-Object { HasChanges $_ 'PhoneChanges' }
        $addressContacts = $updated | Where-Object { HasChanges $_ 'AddressChanges' }
        $relationshipContacts = $updated | Where-Object { HasChanges $_ 'RelationshipChanges' }

        $html += @"
        <div class="section">
            <h2 class="section-title">Updated Contacts ($($updated.Count))</h2>
            <div class="summary-cards">
                <div class="card"><div class="card-header"><div class="card-title">Email Changes</div><div class="card-icon updated">@</div></div><div class="card-value">$($emailContacts.Count)</div><div class="card-description">Contacts with email modifications</div></div>
                <div class="card"><div class="card-header"><div class="card-title">Phone Changes</div><div class="card-icon updated">📞</div></div><div class="card-value">$($phoneContacts.Count)</div><div class="card-description">Contacts with phone modifications</div></div>
                <div class="card"><div class="card-header"><div class="card-title">Address Changes</div><div class="card-icon updated">🏠</div></div><div class="card-value">$($addressContacts.Count)</div><div class="card-description">Contacts with address modifications</div></div>
                <div class="card"><div class="card-header"><div class="card-title">Relationship Changes</div><div class="card-icon updated">👥</div></div><div class="card-value">$($relationshipContacts.Count)</div><div class="card-description">Contacts with relationship modifications</div></div>
            </div>
            <div style="margin-bottom: 1rem;"><button id="expandAllContactsBtn" style="margin-right: .5rem;">Expand All</button><button id="collapseAllContactsBtn">Collapse All</button></div>
"@

        function RenderChangeSummary($changes) {
            $parts = @()
            if ($changes.Added.Count -gt 0) { $parts += "Added: $($changes.Added.Count)" }
            if ($changes.Modified.Count -gt 0) { $parts += "Modified: $($changes.Modified.Count)" }
            if ($changes.Removed.Count -gt 0) { $parts += "Removed: $($changes.Removed.Count)" }
            return ($parts -join ', ')
        }

        function RenderRelationshipDetails($modified) {
            $out = ""
            if ($modified.PSObject.Properties.Name -contains 'StudentNumber') {
                $out += "Student: $($modified.StudentNumber)"
            }
            
            # Only show simplified relationship type changes, not the full object
            if ($modified.PSObject.Properties.Name -contains 'Changes' -and $modified.Changes) {
                if ($out) { $out += " - Changes: " } else { $out += "Changes: " }
                $changes = @()
                foreach ($c in $modified.Changes) {
                    $changes += "$($c.Field): '$($c.OldValue)' → '$($c.NewValue)'"
                }
                $out += ($changes -join '; ')
            }
            return $out
        }

        function RenderChangeItem($item, $changeType, $action) {
            $content = ""
            switch ($changeType) {
                'RelationshipChanges' { $content = RenderRelationshipDetails $item }
                'EmailChanges' { $content = RenderEmailDetails $item }
                'PhoneChanges' { $content = RenderPhoneDetails $item }
                'AddressChanges' { $content = RenderAddressDetails $item }
                default { $content = "$item" }
            }
            return "<div><span class='change-type $($action.ToLower())'>$($action.ToUpper())</span> $((Encode-Html $content))</div>"
        }

        function RenderEmailDetails($item) {
            if ($item.PSObject.Properties.Name -contains 'EmailAddress') {
                return $item.EmailAddress
            }
            return "$item"
        }

        function RenderPhoneDetails($item) {
            $phoneDisplay = ""
            $phoneType = ""
            
            # Get the phone number display
            if ($item.PSObject.Properties.Name -contains 'DisplayNumber') {
                $phoneDisplay = $item.DisplayNumber
            } elseif ($item.PSObject.Properties.Name -contains 'PhoneNumber') {
                $phoneDisplay = $item.PhoneNumber
            } else {
                $phoneDisplay = "$item"
            }
            
            # Get the phone type based on the structure
            if ($item.PSObject.Properties.Name -contains 'Phone' -and $item.Phone) {
                # For Added phones
                if ($item.Phone.PSObject.Properties.Name -contains 'PhoneType') {
                    $phoneType = $item.Phone.PhoneType
                }
                # For Removed phones (PowerSchool format)
                elseif ($item.Phone.PSObject.Properties.Name -contains 'phonenumber_type') {
                    $phoneType = $item.Phone.phonenumber_type
                }
            }
            # For Modified phones, show the change details
            elseif ($item.PSObject.Properties.Name -contains 'Changes' -and $item.Changes) {
                foreach ($change in $item.Changes) {
                    if ($change.Field -eq 'PhoneType') {
                        return "$phoneDisplay ($($change.OldValue) → $($change.NewValue))"
                    }
                }
                # If no phone type change, get from OldPhone or NewPhone
                if ($item.PSObject.Properties.Name -contains 'OldPhone' -and $item.OldPhone.PSObject.Properties.Name -contains 'phonenumber_type') {
                    $phoneType = $item.OldPhone.phonenumber_type
                }
                elseif ($item.PSObject.Properties.Name -contains 'NewPhone' -and $item.NewPhone.PSObject.Properties.Name -contains 'PhoneType') {
                    $phoneType = $item.NewPhone.PhoneType
                }
            }
            
            # Return phone number with type if available
            if ($phoneType) {
                return "$phoneDisplay ($phoneType)"
            } else {
                return $phoneDisplay
            }
        }

        function RenderAddressDetails($item) {
            if ($item.PSObject.Properties.Name -contains 'DisplayAddress') {
                return $item.DisplayAddress
            } else {
                $parts = @()
                if ($item.PSObject.Properties.Name -contains 'StreetAddress') { $parts += $item.StreetAddress }
                if ($item.PSObject.Properties.Name -contains 'City') { $parts += $item.City }
                if ($item.PSObject.Properties.Name -contains 'State') { $parts += $item.State }
                if ($item.PSObject.Properties.Name -contains 'PostalCode') { $parts += $item.PostalCode }
                if ($parts.Count -gt 0) { return ($parts -join ', ') }
            }
            return "$item"
        }

        function RenderContactRow($contact, $prop) {
            $summary = ''
            if ($contact.PSObject.Properties.Name -contains $prop) { 
                $summary = RenderChangeSummary $contact.$prop 
            }
            
            # Extract contact information
            $finalSiteId = $contact.MatchKey
            $powerSchoolId = 'N/A'
            $contactName = 'Unknown'
            
            # Get PowerSchool Contact ID and name if available
            if ($contact.PSObject.Properties.Name -contains 'PowerSchoolPerson' -and $contact.PowerSchoolPerson) {
                $powerSchoolId = $contact.PowerSchoolPerson.person_id
                $firstName = $contact.PowerSchoolPerson.person_firstname
                $lastName = $contact.PowerSchoolPerson.person_lastname
                if ($firstName -or $lastName) {
                    $contactName = @($firstName, $lastName) | Where-Object { $_ } | Join-String -Separator ' '
                }
            }
            # Fallback to CSV contact name if PowerSchool person not available
            elseif ($contact.PSObject.Properties.Name -contains 'CsvContact' -and $contact.CsvContact) {
                $firstName = $contact.CsvContact.FirstName
                $lastName = $contact.CsvContact.LastName
                $middleName = $contact.CsvContact.MiddleName
                if ($firstName -or $lastName) {
                    $contactName = @($firstName, $middleName, $lastName) | Where-Object { $_ } | Join-String -Separator ' '
                }
            }
            
            $rowHtml = "<tr class='collapsible'><td style='font-family:monospace; font-size: 0.85rem;'>$finalSiteId</td><td style='font-family:monospace; font-size: 0.85rem;'>$powerSchoolId</td><td><strong>$contactName</strong></td><td>$((Encode-Html $summary))</td></tr>"
            $rowHtml += "<tr class='collapsible-content'><td colspan='4' style='background:#f9fafb;padding:.75rem;'>"
            
            if ($contact.PSObject.Properties.Name -contains $prop) {
                $changes = $contact.$prop
                if ($changes.Added -and $changes.Added.Count -gt 0) {
                    foreach ($a in $changes.Added) { 
                        $rowHtml += RenderChangeItem $a $prop 'added'
                    }
                }
                if ($changes.Modified -and $changes.Modified.Count -gt 0) {
                    foreach ($m in $changes.Modified) { 
                        $rowHtml += RenderChangeItem $m $prop 'modified'
                    }
                }
                if ($changes.Removed -and $changes.Removed.Count -gt 0) {
                    foreach ($r in $changes.Removed) { 
                        $rowHtml += RenderChangeItem $r $prop 'removed'
                    }
                }
            }
            
            $rowHtml += "</td></tr>"
            return $rowHtml
        }

        function RenderGroup($contacts, $title, $prop, $keySuffix) {
            if ($contacts.Count -eq 0) { return '' }
            
            $s = "<div class='contact-group' style='margin-bottom:1.5rem;'><h3 class='group-header'>$title ($($contacts.Count))</h3><table class='data-table'><thead><tr><th>Final Site Contact ID</th><th>PowerSchool Contact ID</th><th>Name</th><th>Summary</th></tr></thead><tbody>"
            
            # Render first 10 contacts
            $first = $contacts | Select-Object -First 10
            foreach ($c in $first) {
                $s += RenderContactRow $c $prop
            }
            
            if ($contacts.Count -gt 10) {
                $s += "<tr class='show-all-row'><td colspan='4' style='text-align:center;padding:1rem;'><button onclick=`"showAllContactsInGroup(this,'$keySuffix')`">Show All $($contacts.Count) Contacts</button></td></tr>"
                $s += "</tbody><tbody class='hidden-contacts-$keySuffix' style='display:none;'>"
                
                # Render remaining contacts
                $rest = $contacts | Select-Object -Skip 10
                foreach ($c in $rest) {
                    $s += RenderContactRow $c $prop
                }
                $s += "</tbody>"
            } else {
                $s += "</tbody>"
            }
            
            $s += "</table></div>"
            return $s
        }

        $html += RenderGroup $emailContacts '📧 Email Changes' 'EmailChanges' 'email'
        $html += RenderGroup $phoneContacts '📞 Phone Changes' 'PhoneChanges' 'phone'
        $html += RenderGroup $addressContacts '🏠 Address Changes' 'AddressChanges' 'address'
        $html += RenderGroup $relationshipContacts '👥 Relationship Changes' 'RelationshipChanges' 'relationship'

        $html += "</div>"
    }

    # Add metadata section
    $html += @"
        
        <div class="metadata">
            <h3>Report Metadata</h3>
            <div class="metadata-grid">
                <span class="metadata-label">Generated:</span>
                <span class="metadata-value">$reportDate</span>
                
                <span class="metadata-label">Student Changes File:</span>
                <span class="metadata-value">$StudentChangesPath</span>
                
                <span class="metadata-label">Contact Changes File:</span>
                <span class="metadata-value">$ContactChangesPath</span>
                
                <span class="metadata-label">Student Match Field:</span>
                <span class="metadata-value">$($studentChanges.Summary.MatchField)</span>
                
                <span class="metadata-label">Students in CSV:</span>
                <span class="metadata-value">$($studentChanges.Summary.TotalInCsv)</span>
                
                <span class="metadata-label">Students in PowerSchool:</span>
                <span class="metadata-value">$($studentChanges.Summary.TotalInPowerSchool)</span>
                
                <span class="metadata-label">Contacts in CSV:</span>
                <span class="metadata-value">$($contactChanges.Summary.TotalInCsv)</span>
                
                <span class="metadata-label">Contacts in PowerSchool:</span>
                <span class="metadata-value">$($contactChanges.Summary.TotalInPowerSchool)</span>
            </div>
        </div>
    </div>
</body>
</html>
"@

    # Write the HTML file
    Write-Host "Writing HTML report to: $OutputPath" -ForegroundColor Yellow
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host ""; Write-Host "=== Report Generated Successfully ===" -ForegroundColor Green
    Write-Host "  Report saved to: $OutputPath" -ForegroundColor White
    Write-Host "  Total students analyzed: $($studentChanges.Summary.TotalInCsv)" -ForegroundColor White
    Write-Host "  Total contacts analyzed: $($contactChanges.Summary.TotalInCsv)" -ForegroundColor White
    Write-Host "  Total changes detected: $($studentChanges.Summary.NewCount + $studentChanges.Summary.UpdatedCount + $contactChanges.New.Count + $contactChanges.Updated.Count)" -ForegroundColor White
    Write-Host ""

    if ($OpenReport) { Start-Process $OutputPath }
}
catch {
    Write-Error "An error occurred: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}