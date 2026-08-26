#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1') -Force
}

Describe 'Merge-PSContactExport' {
    BeforeEach {
        $script:personExportPath = Join-Path $TestDrive 'Person_export.csv'
        @'
PERSON.ID,PERSON.STATECONTACTID,PERSON.FIRSTNAME,PERSON.LASTNAME
501,JFC-parent-1,Daniel,Wall
502,JFC-parent-2,Grace,Wall
'@ | Set-Content -LiteralPath $script:personExportPath
    }

    It 'maps PERSON.ID from PERSON.STATECONTACTID' {
        InModuleScope FSEnrollment-PSSync -Parameters @{ ExportPath = $script:personExportPath } {
            param($ExportPath)
            $data = [PSNormalizedData]::new()
            foreach ($identifier in @('JFC-parent-1', 'JFC-parent-2')) {
                $contact = [PSContact]::new()
                $contact.ContactIdentifier = $identifier
                $data.Contacts.Add($contact)
            }

            $result = $data | Merge-PSContactExport -Path $ExportPath -RequireAllMatches

            [object]::ReferenceEquals($result, $data) | Should -BeTrue
            $result.Contacts.ContactID | Should -Be @('501', '502')
        }
    }

    It 'exports enriched IDs in the Contact ID column' {
        InModuleScope FSEnrollment-PSSync -Parameters @{ ExportPath = $script:personExportPath; OutputPath = (Join-Path $TestDrive 'contacts-update.csv') } {
            param($ExportPath, $OutputPath)
            $data = [PSNormalizedData]::new()
            foreach ($identifier in @('JFC-parent-1', 'JFC-parent-2')) {
                $contact = [PSContact]::new()
                $contact.ContactIdentifier = $identifier
                $contact.LastName = 'Example'
                $data.Contacts.Add($contact)
            }

            $data = Merge-PSContactExport -Data $data -Path $ExportPath -RequireAllMatches
            Export-PSContactImportFile -Data $data -Path $OutputPath | Out-Null
            $rows = @(Import-Csv -LiteralPath $OutputPath)

            $rows.'Contact ID' | Should -Be @('501', '502')
        }
    }

    It 'rejects duplicate state contact identifiers' {
        @'
PERSON.ID,PERSON.STATECONTACTID
501,JFC-parent-1
999,JFC-parent-1
'@ | Set-Content -LiteralPath $script:personExportPath

        InModuleScope FSEnrollment-PSSync -Parameters @{ ExportPath = $script:personExportPath } {
            param($ExportPath)
            $data = [PSNormalizedData]::new()
            $contact = [PSContact]::new()
            $contact.ContactIdentifier = 'JFC-parent-1'
            $data.Contacts.Add($contact)

            { Merge-PSContactExport -Data $data -Path $ExportPath } |
                Should -Throw "*duplicate 'PERSON.STATECONTACTID'*"
        }
    }

    It 'can require every normalized contact to match' {
        InModuleScope FSEnrollment-PSSync -Parameters @{ ExportPath = $script:personExportPath } {
            param($ExportPath)
            $data = [PSNormalizedData]::new()
            $contact = [PSContact]::new()
            $contact.ContactIdentifier = 'JFC-not-imported'
            $data.Contacts.Add($contact)

            { Merge-PSContactExport -Data $data -Path $ExportPath -RequireAllMatches } |
                Should -Throw "*1 of 1 contacts were not found*"
        }
    }

    It 'rejects a conflicting existing ContactID' {
        InModuleScope FSEnrollment-PSSync -Parameters @{ ExportPath = $script:personExportPath } {
            param($ExportPath)
            $data = [PSNormalizedData]::new()
            $contact = [PSContact]::new()
            $contact.ContactIdentifier = 'JFC-parent-1'
            $contact.ContactID = '777'
            $data.Contacts.Add($contact)

            { Merge-PSContactExport -Data $data -Path $ExportPath } |
                Should -Throw "*conflicts with PowerSchool ID '501'*"
        }
    }
}