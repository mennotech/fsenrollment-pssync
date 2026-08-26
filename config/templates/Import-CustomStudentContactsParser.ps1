#Requires -Version 7.0

<#
.SYNOPSIS
Normalizes parent contacts embedded in the custom student CSV export.

.DESCRIPTION
Creates contacts, email addresses, phone numbers, addresses, and student-contact
relationships from each student row. A stable source-derived identifier groups
all rows for a contact and allows the same parent to be reused across siblings.

.PARAMETER CsvData
Rows imported from the custom student CSV.

.PARAMETER TemplateConfig
Configuration from custom_csv_import_1_contacts.psd1.

.OUTPUTS
PSNormalizedData containing contact-related entities.
#>
function Import-CustomStudentContactsParser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$CsvData,

        [Parameter(Mandatory)]
        [hashtable]$TemplateConfig
    )

    $studentTemplatePath = Join-Path $PSScriptRoot "$($TemplateConfig.StudentTemplateName).psd1"
    if (-not (Test-Path -LiteralPath $studentTemplatePath -PathType Leaf)) {
        throw "Student template not found: $studentTemplatePath"
    }

    $studentTemplate = Import-PowerShellDataFile -LiteralPath $studentTemplatePath
    $studentNumberMapping = @($studentTemplate.ColumnMappings | Where-Object EntityProperty -eq 'StudentNumber')
    if ($studentNumberMapping.Count -ne 1) {
        throw "Template '$($TemplateConfig.StudentTemplateName)' must define exactly one StudentNumber mapping."
    }

    $normalizedData = [PSNormalizedData]::new()
    $mappingContext = @{ Sequences = @{} }
    $processedContacts = @{}
    $processedRelationships = @{}

    foreach ($row in $CsvData) {
        $studentNumber = [string](Resolve-ColumnMappingValue -CsvRow $row -Mapping $studentNumberMapping[0] -MappingContext $mappingContext)
        $preferredName = ([string]$row.'Student''s Preferred Name (if different from legal first name)').Trim()
        $studentFirstName = if ($preferredName) { $preferredName } else { ([string]$row.'First Name').Trim() }
        $studentLastName = ([string]$row.'Last Name').Trim()
        $studentName = if ($studentLastName -and $studentFirstName) { "$studentLastName, $studentFirstName" } else { "$studentLastName$studentFirstName" }

        foreach ($parentDefinition in $TemplateConfig.ParentDefinitions) {
            $givenName = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.GivenNameColumn)
            $surname = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.SurnameColumn)
            if (-not $givenName -and -not $surname) {
                continue
            }

            $emailAddress = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.EmailColumn)
            $cellPhone = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.CellPhoneColumn)
            $workPhone = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.WorkPhoneColumn)
            $contactKey = @(
                ([string]$parentDefinition.Role).ToLowerInvariant()
                $givenName.ToLowerInvariant()
                $surname.ToLowerInvariant()
                $emailAddress.ToLowerInvariant()
                ($cellPhone -replace '\D', '')
            ) -join '|'
            $contactIdentifier = Get-CustomContactIdentifier -ContactKey $contactKey -Prefix ([string]$TemplateConfig.ContactIdentifierPrefix)

            if (-not $processedContacts.ContainsKey($contactIdentifier)) {
                $contact = [PSContact]::new()
                $contact.ContactIdentifier = $contactIdentifier
                $contact.FirstName = $givenName
                $contact.LastName = $surname
                $contact.Employer = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.EmployerColumn)
                $contact.IsActive = $true
                $normalizedData.Contacts.Add($contact)

                if ($emailAddress) {
                    $email = [PSEmailAddress]::new()
                    $email.ContactIdentifier = $contactIdentifier
                    $email.EmailAddress = $emailAddress
                    $email.IsPrimary = $true
                    $normalizedData.EmailAddresses.Add($email)
                }

                Add-CustomContactPhone -Data $normalizedData -ContactIdentifier $contactIdentifier -PhoneNumber $cellPhone -PhoneType 'Mobile' -PriorityOrder 1 -IsPreferred $true
                if (($workPhone -replace '\D', '') -ne ($cellPhone -replace '\D', '')) {
                    Add-CustomContactPhone -Data $normalizedData -ContactIdentifier $contactIdentifier -PhoneNumber $workPhone -PhoneType 'Work' -PriorityOrder 2
                }

                $sameAddressValue = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.SameAddressColumn)
                $useStudentAddress = Test-CustomContactAffirmative -Value $sameAddressValue -AffirmativeValues @($TemplateConfig.AffirmativeValues)
                $street = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.StreetColumn)
                $lineTwo = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.LineTwoColumn)
                $city = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.CityColumn)
                $state = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.StateColumns)
                $postalCode = Get-CustomContactColumnValue -Row $row -Columns @($parentDefinition.PostalCodeColumn)

                if ($useStudentAddress) {
                    $street = ([string]$row.'Street Address').Trim()
                    $lineTwo = ([string]$row.'Street Address Line 2').Trim()
                    $city = ([string]$row.City).Trim()
                    $state = ([string]$row.'State / Province').Trim()
                    $postalCode = ([string]$row.'Postal / Zip Code').Trim()
                }

                if ($street -or $lineTwo -or $city -or $state -or $postalCode) {
                    $address = [PSAddress]::new()
                    $address.ContactIdentifier = $contactIdentifier
                    $address.AddressType = 'Home'
                    $address.PriorityOrder = 1
                    $address.Street = $street
                    $address.LineTwo = $lineTwo
                    $address.City = $city
                    $address.State = ConvertTo-NormalizedStateProvince -Value $state -Countries CA -Format Abbreviation -OnInvalid Keep
                    $address.PostalCode = ConvertTo-NormalizedPostalCode -Value $postalCode -Format Spaced -OnInvalid Keep
                    $normalizedData.Addresses.Add($address)
                }

                $processedContacts[$contactIdentifier] = $true
            }

            $relationshipKey = "$contactIdentifier|$studentNumber"
            if (-not $processedRelationships.ContainsKey($relationshipKey)) {
                $relationship = [PSStudentContactRelationship]::new()
                $relationship.ContactIdentifier = $contactIdentifier
                $relationship.StudentNumber = $studentNumber
                $relationship.StudentName = $studentName
                $relationship.ContactPriorityOrder = [int]$parentDefinition.ContactPriorityOrder
                $relationship.RelationshipType = [string]$parentDefinition.RelationshipType
                $relationship.RelationshipNote = Get-CustomContactColumnValue -Row $row -Columns @($TemplateConfig.RelationshipNoteColumn)
                $relationship.IsLegalGuardian = [bool]$TemplateConfig.RelationshipDefaults.IsLegalGuardian
                $relationship.HasCustody = [bool]$TemplateConfig.RelationshipDefaults.HasCustody
                $relationship.LivesWith = [bool]$TemplateConfig.RelationshipDefaults.LivesWith
                $relationship.AllowSchoolPickup = [bool]$TemplateConfig.RelationshipDefaults.AllowSchoolPickup
                $relationship.IsEmergencyContact = [bool]$TemplateConfig.RelationshipDefaults.IsEmergencyContact
                $relationship.ReceivesMail = [bool]$TemplateConfig.RelationshipDefaults.ReceivesMail

                $livesWithValues = @(
                    ([string]$row.'Student Lives With').Trim()
                    ([string]$row.'Student Lives With - Other').Trim()
                ) | Where-Object { $_ }
                if ($livesWithValues.Count -gt 0) {
                    $relationship.LivesWith = Test-CustomContactTerm -Value ($livesWithValues -join ' ') -Terms @($parentDefinition.LivesWithTerms)
                }
                $normalizedData.Relationships.Add($relationship)
                $processedRelationships[$relationshipKey] = $true
            }
        }

        $emergencyDefinition = $TemplateConfig.EmergencyContactDefinition
        $emergencyName = Get-CustomContactColumnValue -Row $row -Columns @($emergencyDefinition.NameColumn)
        $emergencyPhone = Get-CustomContactColumnValue -Row $row -Columns @($emergencyDefinition.PhoneColumn)
        if ($emergencyName -or $emergencyPhone) {
            $emergencyContactKey = @(
                'emergency'
                $emergencyName.ToLowerInvariant()
                ($emergencyPhone -replace '\D', '')
            ) -join '|'
            $emergencyContactIdentifier = Get-CustomContactIdentifier -ContactKey $emergencyContactKey -Prefix ([string]$TemplateConfig.ContactIdentifierPrefix)

            if (-not $processedContacts.ContainsKey($emergencyContactIdentifier)) {
                $emergencyContact = [PSContact]::new()
                $emergencyContact.ContactIdentifier = $emergencyContactIdentifier
                $emergencyContact.FirstName = Get-PersonNamePart -Name $emergencyName -Part First
                $emergencyContact.MiddleName = Get-PersonNamePart -Name $emergencyName -Part Middle
                $emergencyContact.LastName = Get-PersonNamePart -Name $emergencyName -Part Last
                $emergencyContact.IsActive = $true
                $normalizedData.Contacts.Add($emergencyContact)

                Add-CustomContactPhone -Data $normalizedData -ContactIdentifier $emergencyContactIdentifier -PhoneNumber $emergencyPhone -PhoneType 'Mobile' -PriorityOrder 1 -IsPreferred $true
                $processedContacts[$emergencyContactIdentifier] = $true
            }

            $emergencyRelationshipKey = "$emergencyContactIdentifier|$studentNumber"
            if (-not $processedRelationships.ContainsKey($emergencyRelationshipKey)) {
                $emergencyRelationship = [PSStudentContactRelationship]::new()
                $emergencyRelationship.ContactIdentifier = $emergencyContactIdentifier
                $emergencyRelationship.StudentNumber = $studentNumber
                $emergencyRelationship.StudentName = $studentName
                $emergencyRelationship.ContactPriorityOrder = [int]$emergencyDefinition.ContactPriorityOrder
                $emergencyRelationship.RelationshipType = [string]$emergencyDefinition.RelationshipType
                $emergencyRelationship.IsLegalGuardian = $false
                $emergencyRelationship.HasCustody = $false
                $emergencyRelationship.LivesWith = $false
                $emergencyRelationship.AllowSchoolPickup = $false
                $emergencyRelationship.IsEmergencyContact = $true
                $emergencyRelationship.ReceivesMail = $false
                $normalizedData.Relationships.Add($emergencyRelationship)
                $processedRelationships[$emergencyRelationshipKey] = $true
            }
        }
    }

    return $normalizedData
}

function Get-CustomContactColumnValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Row,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Columns
    )

    foreach ($column in $Columns) {
        if ($Row.PSObject.Properties.Name -contains $column) {
            $value = ([string]$Row.$column).Trim()
            if ($value) {
                return $value
            }
        }
    }
    return ''
}

function Get-CustomContactIdentifier {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ContactKey,
        [Parameter(Mandatory)][string]$Prefix
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes($ContactKey)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    $hex = [Convert]::ToHexString($hash).Substring(0, 16).ToLowerInvariant()
    return "$Prefix$hex"
}

function Add-CustomContactPhone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSNormalizedData]$Data,
        [Parameter(Mandatory)][string]$ContactIdentifier,
        [string]$PhoneNumber,
        [Parameter(Mandatory)][string]$PhoneType,
        [Parameter(Mandatory)][int]$PriorityOrder,
        [bool]$IsPreferred = $false
    )

    if ([string]::IsNullOrWhiteSpace($PhoneNumber)) {
        return
    }

    $phone = [PSPhoneNumber]::new()
    $phone.ContactIdentifier = $ContactIdentifier
    $phone.PhoneNumber = $PhoneNumber
    $phone.PhoneType = $PhoneType
    $phone.PriorityOrder = $PriorityOrder
    $phone.IsPreferred = $IsPreferred
    $phone.IsSMS = $false
    $Data.PhoneNumbers.Add($phone)
}

function Test-CustomContactAffirmative {
    [CmdletBinding()]
    param(
        [string]$Value,
        [Parameter(Mandatory)][string[]]$AffirmativeValues
    )

    return $AffirmativeValues -contains ([string]$Value).Trim().ToLowerInvariant()
}

function Test-CustomContactTerm {
    [CmdletBinding()]
    param(
        [string]$Value,
        [Parameter(Mandatory)][string[]]$Terms
    )

    foreach ($term in $Terms) {
        if ($Value -match "(?i)\b$([regex]::Escape($term))") {
            return $true
        }
    }
    return $false
}