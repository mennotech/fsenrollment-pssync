#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1') -Force
    $sourcePath = Join-Path $TestDrive 'custom_csv_import_1.csv'
    @'
"Student Number","First Name","Middle Name(s)","Last Name","Student's Preferred Name (if different from legal first name)","Gender","Birth Date","Applying For Grade","Street Address","Street Address Line 2","City","State / Province","Postal / Zip Code","Mailing Street Address","Mailing Street Address Line 2","Mailing City","Mailing State / Province","Mailing Postal / Zip Code","Church Attending","Denomination","MB Health # - 9 Digit","MB Health # - 6 Digit","Allergies:","Medical Restrictions & Medications:"
880001,Emma,Jordan,Wall,,Female,"May 30, 2013",8,"41084 Road 33 East",,Blumenort,MB,"R0A 0C1",,,,,,"Calvary Church",Christian,122206929,526288,,
880002,Maxwell,Henry,Hiebert,Max,Male,"Aug 31, 2026",2,"30155 Rd 32 E",,Steinbach,Mb,"R5G1 N9","Box 2424","Group 4",steinbach,MB,R5g1n9,"Pansy Chapel",EMC,124822115,387599,,
'@ | Set-Content -LiteralPath $sourcePath
    $script:data = Import-FSCsv -Path $sourcePath -TemplateName 'custom_csv_import_1'
}

Describe 'custom_csv_import_1 template' {
    It 'Imports all source students' {
        $script:data.Students.Count | Should -Be 2
    }

    It 'Keeps source mappings independent of PowerSchool output formats' {
        $script:data.TemplateMetadata.PSObject.Properties.Name | Should -Not -Contain 'OutputMappings'
        @($script:data.TemplateMetadata.ColumnMappings | Where-Object PowerSchoolAPIField).Count | Should -Be 0
    }

    It 'Applies constants and computed values' {
        $student = $script:data.Students | Where-Object LastName -eq 'Wall'

        $student.StudentNumber | Should -Be '880001'
        $student.FTEID | Should -Be '551'
        $student.SchoolID | Should -Be '961453'
        $student.NextSchool | Should -Be '961453'
        $student.EntryDate | Should -Be ([datetime]'2026-08-24')
        $student.HomeRoom | Should -Be 'PP Middle Years'
        $student.EntryCode | Should -Be '100'
        $student.Email | Should -Be 'emmaw31@sc.school'
    }

    It 'Maps preferred names into the core first name' {
        $student = $script:data.Students | Where-Object LastName -eq 'Hiebert'

        $student.FirstName | Should -Be 'Max'
        $student.MiddleName | Should -Be 'Henry'
        $student.LastName | Should -Be 'Hiebert'
        $student.CustomFields.legal_givenname | Should -Be 'Maxwell'
        $student.CustomFields.legal_middlenames | Should -Be 'Henry'
        $student.StudentNumber | Should -Be '880002'
        $student.Email | Should -Be 'maxh37@sc.school'
    }

    It 'Rejects operations outside the ComposeString allowlist' {
        InModuleScope FSEnrollment-PSSync {
            { Invoke-ColumnMappingStringOperation -Value 'test' -Operation @{ Name = 'InvokeCode' } } |
                Should -Throw "Unknown ComposeString operation 'InvokeCode'."
        }
    }

    It 'Increments sequences within each composed prefix' {
        InModuleScope FSEnrollment-PSSync {
            $mapping = @{
                EntityProperty = 'StudentNumber'
                Transform = 'ComposeString'
                Parts = @(
                    @{ Column = 'Prefix' }
                    @{ Sequence = @{ Width = 2 } }
                )
            }
            $context = @{ Sequences = @{} }

            $values = @(
                Resolve-ColumnMappingValue -CsvRow @{ Prefix = '31' } -Mapping $mapping -MappingContext $context
                Resolve-ColumnMappingValue -CsvRow @{ Prefix = '31' } -Mapping $mapping -MappingContext $context
                Resolve-ColumnMappingValue -CsvRow @{ Prefix = '37' } -Mapping $mapping -MappingContext $context
            )

            $values | Should -Be @('3101', '3102', '3701')
        }
    }

    It 'Supports a configured sequence start' {
        InModuleScope FSEnrollment-PSSync {
            $mapping = @{
                EntityProperty = 'StudentNumber'
                Transform = 'ComposeString'
                Parts = @(
                    @{ Column = 'Prefix' }
                    @{ Sequence = @{ Width = 2; Start = 25 } }
                )
            }
            $context = @{ Sequences = @{} }

            $values = @(
                Resolve-ColumnMappingValue -CsvRow @{ Prefix = '31' } -Mapping $mapping -MappingContext $context
                Resolve-ColumnMappingValue -CsvRow @{ Prefix = '31' } -Mapping $mapping -MappingContext $context
            )

            $values | Should -Be @('3125', '3126')
        }
    }

    It 'Normalizes Canadian postal code formats and invalid values' {
        InModuleScope FSEnrollment-PSSync {
            ConvertTo-NormalizedPostalCode -Value 'a1b2 c3' -Format Spaced -OnInvalid Keep |
                Should -Be 'A1B 2C3'
            ConvertTo-NormalizedPostalCode -Value 'A1B 2C3' -Format Compact -OnInvalid Keep |
                Should -Be 'A1B2C3'
            ConvertTo-NormalizedPostalCode -Value 'bad code!' -Format Spaced -OnInvalid Keep |
                Should -Be 'bad code!'
            ConvertTo-NormalizedPostalCode -Value 'bad code!' -Format Spaced -OnInvalid Skip |
                Should -BeNullOrEmpty
            ConvertTo-NormalizedPostalCode -Value 'a1b2c3extra' -Format Compact -OnInvalid Truncate |
                Should -Be 'A1B2C3'
        }
    }

    It 'Normalizes state and province names for allowed countries' {
        InModuleScope FSEnrollment-PSSync {
            ConvertTo-NormalizedStateProvince -Value 'Manitoba' -Countries CA -Format Abbreviation -OnInvalid Keep |
                Should -Be 'MB'
            ConvertTo-NormalizedStateProvince -Value 'mb' -Countries Canada -Format FullName -OnInvalid Keep |
                Should -Be 'Manitoba'
            ConvertTo-NormalizedStateProvince -Value 'New York' -Countries US -Format Abbreviation -OnInvalid Keep |
                Should -Be 'NY'
            ConvertTo-NormalizedStateProvince -Value 'California' -Countries CA -Format Abbreviation -OnInvalid Skip |
                Should -BeNullOrEmpty
            { ConvertTo-NormalizedStateProvince -Value 'California' -Countries CA -Format Abbreviation -OnInvalid Throw } |
                Should -Throw "State/province 'California' is not valid for countries: CA."
        }
    }

    It 'Maps separate physical and mailing address columns' {
        $student = $script:data.Students | Where-Object LastName -eq 'Hiebert'

        $student.Street | Should -Be '30155 Rd 32 E'
        $student.City | Should -Be 'Steinbach'
        $student.State | Should -Be 'MB'
        $student.Zip | Should -Be 'R5G1 N9'
        $student.MailingStreet | Should -Be 'Box 2424 Group 4'
        $student.MailingCity | Should -Be 'steinbach'
        $student.MailingState | Should -Be 'MB'
        $student.MailingZip | Should -Be 'R5G 1N9'
    }

    It 'Falls back to the physical address when mailing fields are blank' {
        $student = $script:data.Students | Where-Object LastName -eq 'Wall'

        $student.MailingStreet | Should -Be '41084 Road 33 East'
        $student.MailingCity | Should -Be 'Blumenort'
        $student.MailingState | Should -Be 'MB'
        $student.MailingZip | Should -Be 'R0A 0C1'
    }

    It 'Stores extension values as custom fields' {
        $student = $script:data.Students | Where-Object LastName -eq 'Wall'

        $student.CustomFields.legal_givenname | Should -Be 'Emma'
        $student.CustomFields.church_name | Should -Be 'Calvary Church'
        $student.CustomFields.church_denomination | Should -Be 'Christian'
        $student.CustomFields.phin_9digit | Should -Be '122206929'
        $student.CustomFields.phin_6digit | Should -Be '526288'
        $student.CustomFields.HAS_FOOD_ALLERGY | Should -BeFalse
    }

    It 'Exports the cleaned PowerSchool student import schema' {
        $outputPath = Join-Path $TestDrive 'students.csv'
        Export-PSStudentImportFile -Data $script:data -Path $outputPath
        $actual = @(Import-Csv $outputPath)

        $actual.Count | Should -Be 2
        ($actual | Where-Object Last_Name -eq 'Wall').Middle_Name | Should -Be 'Jordan'
        ($actual | Where-Object Last_Name -eq 'Wall').'U_StudentsUserFields.legal_givenname' | Should -Be 'Emma'
        ($actual | Where-Object Last_Name -eq 'Wall').'U_StudentsUserFields.HAS_FOOD_ALLERGY' | Should -BeNullOrEmpty
    }

    It 'Maps normalized custom fields independently for file and API targets' {
        $quickImportMap = Import-PowerShellDataFile (Join-Path $PSScriptRoot '../../config/powerschool-maps/StudentsQuickImport.psd1')
        $quickImportMap.CustomFieldPrefix | Should -Be 'U_StudentsUserFields.'
        @($quickImportMap.Mappings | Where-Object CustomField).Count | Should -Be 0

        InModuleScope FSEnrollment-PSSync -Parameters @{ Metadata = $script:data.TemplateMetadata } {
            param($Metadata)
            $apiMapping = Get-PowerSchoolApiMappings -TemplateMetadata $Metadata |
                Where-Object CustomField -eq 'church_name'

            $apiMapping.PowerSchoolAPIField | Should -Be 'extension.u_studentsuserfields.church_name'
        }
    }

    It 'Rejects an unknown output map' {
        $outputPath = Join-Path $TestDrive 'students.csv'

        { Export-PSStudentImportFile -Data $script:data -Path $outputPath -OutputMapName 'MissingMap' } |
            Should -Throw '*PowerSchool output map not found*'
    }

    It 'Exports TSV when requested by extension' {
        $outputPath = Join-Path $TestDrive 'students.tsv'
        Export-PSStudentImportFile -Data $script:data -Path $outputPath

        @(Import-Csv $outputPath -Delimiter "`t").Count | Should -Be 2
    }
}