#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '../FSEnrollment-PSSync.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Submit-PSContactChange' {
    BeforeEach {
        # Mock the PowerSchool connection
        InModuleScope FSEnrollment-PSSync {
            $script:PowerSchoolToken = ConvertTo-SecureString -String 'test-token-12345' -AsPlainText -Force
            $script:PowerSchoolBaseUrl = 'https://test.powerschool.com'
            $script:PowerSchoolTokenExpiry = (Get-Date).AddHours(1)
        }

        # Create sample change data with TemplateMetadata for contacts
        $script:SampleChanges = [PSCustomObject]@{
            New = @()
            Updated = @()
            Unchanged = @()
            Summary = [PSCustomObject]@{
                TotalInCsv = 0
                TotalInPowerSchool = 0
                NewCount = 0
                UpdatedCount = 0
                UnchangedCount = 0
                MatchField = 'ContactID'
            }
            TemplateMetadata = @{
                TemplateName = 'test_contact_template'
                KeyField = 'ContactID'
                PowerSchoolKeyField = 'person_id'
                PowerSchoolKeyDataType = 'int'
                CheckForChanges = @('FirstName', 'LastName', 'Gender')
                ColumnMappings = @(
                    @{ CSVColumn = 'Contact_ID'; EntityProperty = 'ContactID'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_id' }
                    @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                    @{ CSVColumn = 'Middle_Name'; EntityProperty = 'MiddleName'; EntityType = 'Contact'; PowerSchoolAPIField = 'middleName' }
                    @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                    @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; EntityType = 'Contact'; PowerSchoolAPIField = 'gender' }
                    @{ CSVColumn = 'Employer'; EntityProperty = 'Employer'; EntityType = 'Contact'; PowerSchoolAPIField = 'employer' }
                    @{ CSVColumn = 'Prefix'; EntityProperty = 'Prefix'; EntityType = 'Contact'; PowerSchoolAPIField = 'prefix' }
                    @{ CSVColumn = 'Suffix'; EntityProperty = 'Suffix'; EntityType = 'Contact'; PowerSchoolAPIField = 'suffix' }
                )
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept Changes parameter' {
            InModuleScope FSEnrollment-PSSync {
                Mock Invoke-PowerSchoolApiRequest { return @{ person_id = 12345 } }
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                $templateMetadata = @{
                    TemplateName = 'test_contact_template'
                    KeyField = 'ContactID'
                    PowerSchoolKeyField = 'person_id'
                    PowerSchoolKeyDataType = 'int'
                    CheckForChanges = @('FirstName', 'LastName')
                    ColumnMappings = @(
                        @{ CSVColumn = 'Contact_ID'; EntityProperty = 'ContactID'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_id' }
                        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                    )
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = $templateMetadata
                }
                
                { Submit-PSContactChange -Changes $changes -WhatIf } | Should -Not -Throw
            }
        }

        It 'Should accept JsonPath parameter with valid file' {
            # Create temp JSON file
            $tempFile = New-TemporaryFile
            $script:SampleChanges | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile.FullName
            
            InModuleScope FSEnrollment-PSSync -Parameters @{ TempFile = $tempFile } {
                param($TempFile)
                Mock Invoke-PowerSchoolApiRequest { return @{ person_id = 12345 } }
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                { Submit-PSContactChange -JsonPath $TempFile.FullName -WhatIf } | Should -Not -Throw
            }
            
            Remove-Item $tempFile.FullName
        }

        It 'Should throw error if not connected to PowerSchool' {
            InModuleScope FSEnrollment-PSSync {
                # Clear connection variables
                $script:PowerSchoolToken = $null
                $script:PowerSchoolBaseUrl = $null
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_contact_template'
                        KeyField = 'ContactID'
                        PowerSchoolKeyField = 'person_id'
                        PowerSchoolKeyDataType = 'int'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Contact_ID'; EntityProperty = 'ContactID'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                        )
                    }
                }
                
                { Submit-PSContactChange -Changes $changes } | Should -Throw "*Not connected to PowerSchool*"
            }
        }
        
        It 'Should NOT throw error in WhatIf mode when not connected' {
            InModuleScope FSEnrollment-PSSync {
                # Clear connection variables
                $script:PowerSchoolToken = $null
                $script:PowerSchoolBaseUrl = $null
                
                $templateMetadata = @{
                    TemplateName = 'test_contact_template'
                    KeyField = 'ContactID'
                    PowerSchoolKeyField = 'person_id'
                    PowerSchoolKeyDataType = 'int'
                    CheckForChanges = @('FirstName', 'LastName')
                    ColumnMappings = @(
                        @{ CSVColumn = 'Contact_ID'; EntityProperty = 'ContactID'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_id' }
                        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                    )
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = $templateMetadata
                }
                
                { Submit-PSContactChange -Changes $changes -WhatIf } | Should -Not -Throw
            }
        }

        It 'Should accept Limit parameter' {
            InModuleScope FSEnrollment-PSSync {
                Mock Invoke-PowerSchoolApiRequest { return @{ person_id = 12345 } }
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                $templateMetadata = @{
                    TemplateName = 'test_contact_template'
                    KeyField = 'ContactID'
                    PowerSchoolKeyField = 'person_id'
                    PowerSchoolKeyDataType = 'int'
                    CheckForChanges = @('FirstName', 'LastName')
                    ColumnMappings = @(
                        @{ CSVColumn = 'Contact_ID'; EntityProperty = 'ContactID'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_id' }
                        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                    )
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                    TemplateMetadata = $templateMetadata
                }
                
                { Submit-PSContactChange -Changes $changes -Limit 5 -WhatIf } | Should -Not -Throw
            }
        }
        
        It 'Should throw error if TemplateMetadata is missing' {
            InModuleScope FSEnrollment-PSSync {
                Mock Invoke-PowerSchoolApiRequest { return @{ person_id = 12345 } }
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @()
                }
                
                { Submit-PSContactChange -Changes $changes } | Should -Throw "*TemplateMetadata not found*"
            }
        }
    }

    Context 'New Contact Creation' {
        It 'Should create a new contact successfully' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ 
                        person_id = 12345
                        _success_message = 'Contact created successfully'
                    } 
                }
                
                $newContact = [PSContact]::new()
                $newContact.ContactID = 'C12345'
                $newContact.FirstName = 'Jane'
                $newContact.LastName = 'Smith'
                $newContact.Gender = 'F'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = 'C12345'
                            MatchField = 'ContactID'
                            Contact = $newContact
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_contact_template'
                        KeyField = 'ContactID'
                        PowerSchoolKeyField = 'person_id'
                        CheckForChanges = @('FirstName', 'LastName', 'Gender')
                        ColumnMappings = @(
                            @{ CSVColumn = 'Contact_ID'; EntityProperty = 'ContactID'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_id' }
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                            @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; EntityType = 'Contact'; PowerSchoolAPIField = 'gender' }
                        )
                    }
                }
                
                $result = Submit-PSContactChange -Changes $changes
                
                $result.NewContactsApplied | Should -Be 1
                $result.UpdatedContactsApplied | Should -Be 0
                $result.FailedChanges.Count | Should -Be 0
            }
        }

        It 'Should build correct payload for new contact with demographics' {
            InModuleScope FSEnrollment-PSSync {
                $newContact = [PSContact]::new()
                $newContact.ContactID = 'C12345'
                $newContact.Prefix = 'Dr.'
                $newContact.FirstName = 'Jane'
                $newContact.MiddleName = 'Marie'
                $newContact.LastName = 'Smith'
                $newContact.Suffix = 'Ph.D.'
                $newContact.Gender = 'F'
                $newContact.Employer = 'Acme Corp'
                
                $templateMetadata = @{
                    TemplateName = 'test_contact_template'
                    KeyField = 'ContactID'
                    PowerSchoolKeyField = 'person_id'
                    CheckForChanges = @('FirstName', 'LastName', 'Gender')
                    ColumnMappings = @(
                        @{ CSVColumn = 'Prefix'; EntityProperty = 'Prefix'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_prefix' }
                        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_firstname' }
                        @{ CSVColumn = 'Middle_Name'; EntityProperty = 'MiddleName'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_middlename' }
                        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_lastname' }
                        @{ CSVColumn = 'Suffix'; EntityProperty = 'Suffix'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_suffix' }
                        @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_gender' }
                        @{ CSVColumn = 'Employer'; EntityProperty = 'Employer'; EntityType = 'Contact'; PowerSchoolAPIField = 'person_employer' }
                    )
                }
                
                $payload = Build-ContactPayload -Contact $newContact -TemplateMetadata $templateMetadata
                
                # Contact API uses flat payload structure (no nested objects)
                # Table prefix is stripped by Remove-TablePrefix helper function
                $payload.prefix | Should -Be 'Dr.'
                $payload.firstname | Should -Be 'Jane'
                $payload.middlename | Should -Be 'Marie'
                $payload.lastname | Should -Be 'Smith'
                $payload.suffix | Should -Be 'Ph.D.'
                $payload.gender | Should -Be 'F'
                $payload.employer | Should -Be 'Acme Corp'
            }
        }
    }

    Context 'Contact Updates' {
        It 'Should update an existing contact successfully' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ 
                        person_id = 12345
                        _success_message = 'Contact updated successfully'
                    } 
                }
                
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'Jane'
                    person_middlename = 'Marie'
                    person_lastname = 'Smith'
                    person_gender_code = 'F'
                }
                
                $changes = [PSCustomObject]@{
                    New = @()
                    Updated = @(
                        [PSCustomObject]@{
                            MatchKey = 'C12345'
                            MatchField = 'ContactID'
                            PowerSchoolPerson = $psPerson
                            Changes = @(
                                [PSCustomObject]@{
                                    Field = 'FirstName'
                                    PowerSchoolField = 'person_firstname'
                                    PowerSchoolAPIField = 'firstName'
                                    OldValue = 'Jane'
                                    NewValue = 'Janet'
                                }
                            )
                        }
                    )
                    TemplateMetadata = @{
                        TemplateName = 'test_contact_template'
                        KeyField = 'ContactID'
                        PowerSchoolKeyField = 'person_id'
                        CheckForChanges = @('FirstName', 'LastName', 'Gender')
                        ColumnMappings = @(
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                            @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; EntityType = 'Contact'; PowerSchoolAPIField = 'gender' }
                        )
                    }
                }
                
                $result = Submit-PSContactChange -Changes $changes
                
                $result.NewContactsApplied | Should -Be 0
                $result.UpdatedContactsApplied | Should -Be 1
                $result.FailedChanges.Count | Should -Be 0
            }
        }

        It 'Should build correct payload for contact update' {
            InModuleScope FSEnrollment-PSSync {
                $psPerson = [PSCustomObject]@{
                    person_id = 12345
                    person_firstname = 'Jane'
                    person_lastname = 'Smith'
                    person_gender_code = 'F'
                }
                
                $changes = @(
                    [PSCustomObject]@{
                        Field = 'FirstName'
                        PowerSchoolAPIField = 'firstName'
                        OldValue = 'Jane'
                        NewValue = 'Janet'
                    }
                    [PSCustomObject]@{
                        Field = 'LastName'
                        PowerSchoolAPIField = 'lastName'
                        OldValue = 'Smith'
                        NewValue = 'Johnson'
                    }
                )
                
                $templateMetadata = @{
                    TemplateName = 'test_contact_template'
                    KeyField = 'ContactID'
                    PowerSchoolKeyField = 'person_id'
                    ColumnMappings = @(
                        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                    )
                }
                
                $payload = Build-ContactUpdatePayload -Changes $changes -ContactID '12345' -PowerSchoolPerson $psPerson -TemplateMetadata $templateMetadata
                
                $payload.firstName | Should -Be 'Janet'
                $payload.lastName | Should -Be 'Johnson'
                $payload.Keys.Count | Should -Be 2
            }
        }
    }

    Context 'WhatIf Mode' {
        It 'Should work in WhatIf mode without connection' {
            InModuleScope FSEnrollment-PSSync {
                # Clear connection variables to simulate no connection
                $script:PowerSchoolToken = $null
                $script:PowerSchoolBaseUrl = $null
                
                $newContact = [PSContact]::new()
                $newContact.ContactID = 'C12345'
                $newContact.FirstName = 'Jane'
                $newContact.LastName = 'Smith'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = 'C12345'
                            MatchField = 'ContactID'
                            Contact = $newContact
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_contact_template'
                        KeyField = 'ContactID'
                        PowerSchoolKeyField = 'person_id'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                        )
                    }
                }
                
                { Submit-PSContactChange -Changes $changes -WhatIf } | Should -Not -Throw
            }
        }

        It 'Should show zero applied changes in WhatIf mode' {
            InModuleScope FSEnrollment-PSSync {
                $newContact = [PSContact]::new()
                $newContact.ContactID = 'C12345'
                $newContact.FirstName = 'Jane'
                $newContact.LastName = 'Smith'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = 'C12345'
                            MatchField = 'ContactID'
                            Contact = $newContact
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_contact_template'
                        KeyField = 'ContactID'
                        PowerSchoolKeyField = 'person_id'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                        )
                    }
                }
                
                $result = Submit-PSContactChange -Changes $changes -WhatIf
                
                $result.NewContactsApplied | Should -Be 0
                $result.UpdatedContactsApplied | Should -Be 0
                $result.Summary.TotalApplied | Should -Be 0
            }
        }
    }

    Context 'Error Handling' {
        It 'Should track failed changes when API call fails' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    throw "API Error: Contact creation failed"
                }
                
                $newContact = [PSContact]::new()
                $newContact.ContactID = 'C12345'
                $newContact.FirstName = 'Jane'
                $newContact.LastName = 'Smith'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = 'C12345'
                            MatchField = 'ContactID'
                            Contact = $newContact
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_contact_template'
                        KeyField = 'ContactID'
                        PowerSchoolKeyField = 'person_id'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                        )
                    }
                }
                
                $result = Submit-PSContactChange -Changes $changes -WarningAction SilentlyContinue
                
                $result.NewContactsApplied | Should -Be 0
                $result.FailedChanges.Count | Should -Be 1
                $result.FailedChanges[0].Type | Should -Be 'New'
                $result.FailedChanges[0].MatchKey | Should -Be 'C12345'
            }
        }
    }

    Context 'Limit Parameter' {
        It 'Should respect Limit parameter' {
            InModuleScope FSEnrollment-PSSync {
                Mock Test-PowerSchoolConnection { }
                Mock Get-PowerSchoolAccessToken { return (ConvertTo-SecureString -String 'test-token' -AsPlainText -Force) }
                Mock Invoke-PowerSchoolApiRequest { 
                    return @{ 
                        person_id = 12345
                        _success_message = 'Contact created successfully'
                    } 
                }
                
                $contact1 = [PSContact]::new()
                $contact1.ContactID = 'C12345'
                $contact1.FirstName = 'Jane'
                $contact1.LastName = 'Smith'
                
                $contact2 = [PSContact]::new()
                $contact2.ContactID = 'C67890'
                $contact2.FirstName = 'John'
                $contact2.LastName = 'Doe'
                
                $contact3 = [PSContact]::new()
                $contact3.ContactID = 'C11111'
                $contact3.FirstName = 'Bob'
                $contact3.LastName = 'Johnson'
                
                $changes = [PSCustomObject]@{
                    New = @(
                        [PSCustomObject]@{
                            MatchKey = 'C12345'
                            MatchField = 'ContactID'
                            Contact = $contact1
                        }
                        [PSCustomObject]@{
                            MatchKey = 'C67890'
                            MatchField = 'ContactID'
                            Contact = $contact2
                        }
                        [PSCustomObject]@{
                            MatchKey = 'C11111'
                            MatchField = 'ContactID'
                            Contact = $contact3
                        }
                    )
                    Updated = @()
                    TemplateMetadata = @{
                        TemplateName = 'test_contact_template'
                        KeyField = 'ContactID'
                        PowerSchoolKeyField = 'person_id'
                        CheckForChanges = @('FirstName', 'LastName')
                        ColumnMappings = @(
                            @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; EntityType = 'Contact'; PowerSchoolAPIField = 'firstName' }
                            @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; EntityType = 'Contact'; PowerSchoolAPIField = 'lastName' }
                        )
                    }
                }
                
                $result = Submit-PSContactChange -Changes $changes -Limit 2
                
                $result.NewContactsApplied | Should -Be 2
                $result.Summary.TotalProcessed | Should -Be 2
                $result.Summary.LimitApplied | Should -Be $true
            }
        }
    }
}
