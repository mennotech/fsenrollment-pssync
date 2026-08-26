#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1') -Force
    $sourcePath = Join-Path $TestDrive 'custom_csv_import_1_contacts.csv'
    @'
"Student Number","First Name","Last Name","Student's Preferred Name (if different from legal first name)","Applying For Grade","Street Address","Street Address Line 2","City","State / Province","Postal / Zip Code","Emergency Contact Name:","Emergency Contact Phone:","Father’s Surname","Father’s Given Name","Father's Address same as student","Father's Street Address","Father's Street Address Line 2","Father's City","Father's State / Province","Father's Postal / Zip Code","Father’s Workplace","Father’s Work Number","Father’s Cell Number","Father’s Email","Mother’s Surname","Mother’s Given Name","Mother's Address same as student","Mother's Street Address","Mother's Street Address Line 2","Mother's City","Mother's State / Province","Mother's Postal / Zip Code","Mother’s Workplace","Mother’s Work Number","Mother’s Cell Number","Mother’s Email","Student Lives With","Student Lives With - Other","Custody Description - Other"
990001,Emma,Wall,,8,"101 Cedar Lane",,Winnipeg,MB,"R3C 1A1","Jordan Reed","204-555-0199",Wall,Daniel,Yes,,,,,,"Prairie Works","204-555-0101","204-555-0102",daniel.wall@example.com,Wall,Grace,Yes,,,,,,"River Clinic",,"204-555-0103",grace.wall@example.com,"Both Parents",,"Review custody documentation"
990002,Noah,Wall,,8,"101 Cedar Lane",,Winnipeg,MB,"R3C 1A1","Jordan Reed","204-555-0199",Wall,Daniel,Yes,,,,,,"Prairie Works","204-555-0101","204-555-0102",daniel.wall@example.com,Wall,Grace,Yes,,,,,,"River Clinic",,"204-555-0103",grace.wall@example.com,,,"Review custody documentation"
'@ | Set-Content -LiteralPath $sourcePath

    $script:data = Import-FSCsv -Path $sourcePath -TemplateName 'custom_csv_import_1_contacts'
    $script:outputPath = Join-Path $TestDrive 'contacts.csv'
    Export-PSContactImportFile -Data $script:data -Path $script:outputPath
    $script:rows = @(Import-Csv -LiteralPath $script:outputPath)
}

Describe 'custom_csv_import_1_contacts template' {
    It 'Creates one contact per unique parent across siblings' {
        $script:data.Contacts.Count | Should -Be 3
        $script:data.EmailAddresses.Count | Should -Be 2
        $script:data.PhoneNumbers.Count | Should -Be 4
        $script:data.Addresses.Count | Should -Be 2
    }

    It 'Uses source student numbers for relationships' {
        $script:data.Relationships.Count | Should -Be 6
        @($script:data.Relationships.StudentNumber | Sort-Object -Unique) | Should -Be @('990001', '990002')
        @($script:data.Relationships.RelationshipType | Sort-Object -Unique) | Should -Be @('Father', 'Mother', 'Other')
    }

    It 'Uses the student address only when explicitly configured by the source row' {
        $script:data.Addresses.Street | Should -Be @('101 Cedar Lane', '101 Cedar Lane')
        $script:data.Addresses.State | Should -Be @('MB', 'MB')
        $script:data.Addresses.PostalCode | Should -Be @('R3C 1A1', 'R3C 1A1')
    }

    It 'Prioritizes mothers over fathers' {
        @($script:data.Relationships | Where-Object RelationshipType -eq 'Mother').ContactPriorityOrder |
            Should -Be @(1, 1)
        @($script:data.Relationships | Where-Object RelationshipType -eq 'Father').ContactPriorityOrder |
            Should -Be @(2, 2)
    }

    It 'Defaults parent relationship flags except emergency to true' {
        foreach ($relationship in $script:data.Relationships | Where-Object RelationshipType -ne 'Other') {
            $relationship.IsLegalGuardian | Should -BeTrue
            $relationship.HasCustody | Should -BeTrue
            $relationship.AllowSchoolPickup | Should -BeTrue
            $relationship.IsEmergencyContact | Should -BeFalse
            $relationship.ReceivesMail | Should -BeTrue
            $relationship.LivesWith | Should -BeTrue
        }
    }

    It 'Creates one emergency contact across siblings with only its emergency flag true' {
        $emergencyRelationships = @($script:data.Relationships | Where-Object RelationshipType -eq 'Other')
        $emergencyContactIds = @($emergencyRelationships.ContactIdentifier | Sort-Object -Unique)

        $emergencyRelationships.Count | Should -Be 2
        $emergencyContactIds.Count | Should -Be 1
        ($script:data.Contacts | Where-Object ContactIdentifier -eq $emergencyContactIds[0]).FirstName | Should -Be 'Jordan'
        ($script:data.Contacts | Where-Object ContactIdentifier -eq $emergencyContactIds[0]).LastName | Should -Be 'Reed'
        foreach ($relationship in $emergencyRelationships) {
            $relationship.ContactPriorityOrder | Should -Be 3
            $relationship.IsLegalGuardian | Should -BeFalse
            $relationship.HasCustody | Should -BeFalse
            $relationship.LivesWith | Should -BeFalse
            $relationship.AllowSchoolPickup | Should -BeFalse
            $relationship.IsEmergencyContact | Should -BeTrue
            $relationship.ReceivesMail | Should -BeFalse
        }
    }

    It 'Exports the official PowerSchool 2022.09 contact schema' {
        $script:rows.Count | Should -Be 6
        @($script:rows[0].PSObject.Properties.Name).Count | Should -Be 75
        $script:rows[0].PSObject.Properties.Name[0] | Should -Be 'New Contact Identifier'
        $script:rows[0].PSObject.Properties.Name[-1] | Should -Be 'STUDENTCONTACTDETAILCOREFIELDS.isVolunteer'
        @($script:rows.'New Contact Identifier' | Sort-Object -Unique).Count | Should -Be 3
        @($script:rows.studentNumber | Where-Object { $_ } | Sort-Object -Unique) | Should -Be @('990001', '990002')
        @($script:rows | Where-Object 'Relationship Type' -eq 'Other').'Is Emergency Contact' | Should -Be @(1, 1)
        @($script:rows | Where-Object 'Relationship Type' -ne 'Other' | Where-Object studentNumber).'Is Emergency Contact' | Should -Be @(0, 0, 0, 0)
    }

    It 'Leaves update IDs blank for new contacts and associations' {
        $script:rows.'Contact ID' | Where-Object { $_ } | Should -BeNullOrEmpty
        $script:rows.'Student Contact ID' | Where-Object { $_ } | Should -BeNullOrEmpty
        $script:rows.'Student Contact Detail ID' | Where-Object { $_ } | Should -BeNullOrEmpty
    }
}