#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1') -Force
}

Describe 'PSStudent custom fields' {
    It 'Maps a source column into the custom field collection' {
        InModuleScope FSEnrollment-PSSync {
            $student = [PSStudent]::new()
            $row = [PSCustomObject]@{ LegalName = 'Jane' }
            $mapping = @{ CSVColumn = 'LegalName'; CustomField = 'LegalGivenName'; DataType = 'string' }

            Invoke-ColumnMapping -CsvRow $row -Entity $student -ColumnMappings @($mapping)

            $student.CustomFields.LegalGivenName | Should -Be 'Jane'
        }
    }

    It 'Adds mapped custom fields to a new student API payload' {
        InModuleScope FSEnrollment-PSSync {
            $student = [PSStudent]::new()
            $student.StudentNumber = '1234'
            $student.CustomFields.LegalGivenName = 'Jane'
            $metadata = [PSCustomObject]@{
                ColumnMappings = @(
                    [PSCustomObject]@{
                        CustomField = 'LegalGivenName'
                        PowerSchoolAPIField = 'extension.u_studentsuserfields.legal_givenname'
                    }
                )
            }

            $payload = Build-StudentPayload -Student $student -TemplateMetadata $metadata

            $tableExtension = $payload.students.student._extension_data._table_extension
            $tableExtension.name | Should -Be 'u_studentsuserfields'
            ($tableExtension._field | Where-Object name -eq 'legal_givenname').value | Should -Be 'Jane'
        }
    }

    It 'Reconstructs custom fields from deserialized data' {
        InModuleScope FSEnrollment-PSSync {
            $source = [PSCustomObject]@{
                StudentNumber = '1234'
                CustomFields = [PSCustomObject]@{ ChurchName = 'Example Church' }
            }

            $student = [PSStudent]::FromObject($source)

            $student.CustomFields.ChurchName | Should -Be 'Example Church'
        }
    }
}