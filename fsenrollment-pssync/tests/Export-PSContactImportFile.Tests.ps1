#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $modulePath -Force

    $testDataPath = Join-Path $PSScriptRoot '../../data/examples/fs_powerschool_nonapi_report/parents_example.csv'
    $script:contactData = Import-FSCsv -Path $testDataPath -TemplateName 'fs_powerschool_nonapi_report_parents'
    $script:expectedRowCount = 0
    foreach ($contact in $script:contactData.Contacts) {
        $identifier = $contact.ContactIdentifier
        $emailCount = @($script:contactData.EmailAddresses | Where-Object ContactIdentifier -eq $identifier).Count
        $phoneCount = @($script:contactData.PhoneNumbers | Where-Object ContactIdentifier -eq $identifier).Count
        $addressCount = @($script:contactData.Addresses | Where-Object ContactIdentifier -eq $identifier).Count
        $relationshipCount = @($script:contactData.Relationships | Where-Object ContactIdentifier -eq $identifier).Count
        $script:expectedRowCount += [Math]::Max(1, [Math]::Max($emailCount, [Math]::Max($phoneCount, [Math]::Max($addressCount, $relationshipCount))))
    }
}

Describe 'Export-PSContactImportFile' {
    BeforeEach {
        $script:outputPath = Join-Path $TestDrive 'contacts.csv'
    }

    It 'Exports CSV using the PowerSchool contact import schema' {
        $result = Export-PSContactImportFile -Data $script:contactData -Path $script:outputPath
        $rows = @(Import-Csv -LiteralPath $script:outputPath)

        $result.FullName | Should -Be $script:outputPath
        $rows.Count | Should -Be $script:expectedRowCount
        $rows[0].PSObject.Properties.Name.Count | Should -Be 76
        $rows[0].PSObject.Properties.Name[0] | Should -Be 'New Contact Identifier'
        $rows[0].PSObject.Properties.Name[-1] | Should -Be 'STUDENTCONTACTDETAILCOREFIELDS.isVolunteer'
    }

    It 'Uses the maintained ContactsDataImportManager map' {
        $mapPath = Join-Path $PSScriptRoot '../../config/powerschool-maps/ContactsDataImportManager.psd1'
        $map = Import-PowerShellDataFile -LiteralPath $mapPath

        $map.MapName | Should -Be 'ContactsDataImportManager'
        @($map.Mappings).Count | Should -Be 76
        @($map.Mappings.OutputColumn | Select-Object -Unique).Count | Should -Be 76
        $map.Mappings[0].OutputColumn | Should -Be 'New Contact Identifier'
        $map.Mappings[-1].OutputColumn | Should -Be 'STUDENTCONTACTDETAILCOREFIELDS.isVolunteer'
    }

    It 'Maps normalized contact and related entity values' {
        Export-PSContactImportFile -Data $script:contactData -Path $script:outputPath
        $rows = @(Import-Csv -LiteralPath $script:outputPath)
        $firstContact = $script:contactData.Contacts[0]
        $contactRows = @($rows | Where-Object { $_.'New Contact Identifier' -eq $firstContact.ContactIdentifier })

        $contactRows[0].'First Name' | Should -Be $firstContact.FirstName
        $contactRows[0].'Last Name' | Should -Be $firstContact.LastName
        $contactRows[0].'State Contact ID' | Should -Be $firstContact.ContactIdentifier
        $contactRows[0].'Email Address' | Should -Not -BeNullOrEmpty
        $contactRows[0].phoneNumberAsEntered | Should -Not -BeNullOrEmpty
        $contactRows[0].studentNumber | Should -Not -BeNullOrEmpty
        $contactRows[0].'Relationship Type' | Should -Not -BeNullOrEmpty
    }

    It 'Infers TSV format from the file extension' {
        $script:outputPath = Join-Path $TestDrive 'contacts.tsv'
        Export-PSContactImportFile -Data $script:contactData -Path $script:outputPath
        $rows = @(Import-Csv -LiteralPath $script:outputPath -Delimiter "`t")

        $rows.Count | Should -Be $script:expectedRowCount
        (Get-Content -LiteralPath $script:outputPath -TotalCount 1) | Should -Match "`t"
    }

    It 'Supports an explicit TSV format' {
        Export-PSContactImportFile -Data $script:contactData -Path $script:outputPath -Format Tsv
        $rows = @(Import-Csv -LiteralPath $script:outputPath -Delimiter "`t")

        $rows.Count | Should -Be $script:expectedRowCount
    }

    It 'Rejects a contact without an import identifier or PowerSchool ID' {
        InModuleScope FSEnrollment-PSSync -Parameters @{ OutputPath = $script:outputPath } {
            param($OutputPath)
            $data = [PSNormalizedData]::new()
            $contact = [PSContact]::new()
            $contact.FirstName = 'No'
            $contact.LastName = 'Identifier'
            $data.Contacts.Add($contact)

            { Export-PSContactImportFile -Data $data -Path $OutputPath -ErrorAction Stop } | Should -Throw '*neither ContactIdentifier nor ContactID*'
        }
    }

    It 'Rejects an unknown output map' {
        { Export-PSContactImportFile -Data $script:contactData -Path $script:outputPath -OutputMapName 'MissingMap' } |
            Should -Throw '*PowerSchool output map not found*'
    }
}