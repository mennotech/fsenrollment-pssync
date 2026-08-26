#Requires -Version 7.0

<#
.SYNOPSIS
    Exports normalized contact data for PowerSchool Data Import Manager.

.DESCRIPTION
    Converts contacts and their email addresses, phone numbers, addresses, and
    student relationships from PSNormalizedData into the PowerSchool Student
    Contacts import layout. The output contains the field-name header required
    by Data Import Manager without the instructional rows from PowerSchool's
    blank template.

.PARAMETER Data
    Normalized contact data to export.

.PARAMETER Path
    Destination path for the import file.

.PARAMETER Format
    Delimited file format. If omitted, the format is inferred from a .tsv
    extension; all other extensions use CSV.

.EXAMPLE
    Export-PSContactImportFile -Data $contactData -Path './contacts.csv'

.EXAMPLE
    $contactData | Export-PSContactImportFile -Path './contacts.tsv' -Format Tsv

.INPUTS
    PSNormalizedData

.OUTPUTS
    System.IO.FileInfo

.NOTES
    Uses the PowerSchool Student Contacts Data Import Template 2022.09 field
    names and order. Contacts marked ExcludeFromExport are omitted.
#>
function Export-PSContactImportFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSNormalizedData]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Csv', 'Tsv')]
        [string]$Format
    )

    process {
        $outputFormat = if ($Format) {
            $Format
        }
        elseif ([System.IO.Path]::GetExtension($Path) -ieq '.tsv') {
            'Tsv'
        }
        else {
            'Csv'
        }
        $delimiter = if ($outputFormat -eq 'Tsv') { "`t" } else { ',' }
        $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $outputDirectory = Split-Path -Path $outputPath -Parent

        if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
            throw "Output directory does not exist: $outputDirectory"
        }

        $fieldNames = @(
            'New Contact Identifier', 'Contact ID', 'Prefix', 'First Name', 'Middle Name', 'Last Name', 'Suffix', 'Gender', 'Employer', 'Is Active',
            'State Contact ID', 'Exclude From State Reporting', 'PERSONCOREFIELDS.countryOfOrigin', 'PERSONCOREFIELDS.dob', 'PERSONCOREFIELDS.educationLevel',
            'PERSONCOREFIELDS.employmentStatus', 'PERSONCOREFIELDS.govWorkLoc', 'PERSONCOREFIELDS.isAvailableAtWork', 'PERSONCOREFIELDS.isDeceased',
            'PERSONCOREFIELDS.isOnActiveDuty', 'PERSONCOREFIELDS.livesOnBase', 'PERSONCOREFIELDS.maidenName', 'PERSONCOREFIELDS.militaryStatus',
            'PERSONCOREFIELDS.needsInterpreterAssist', 'PERSONCOREFIELDS.occupation', 'PERSONCOREFIELDS.payGrade', 'PERSONCOREFIELDS.serviceBranch',
            'PERSONCOREFIELDS.ssn', 'Email Address', 'Contact Email Address ID', 'Email Type', 'Is Primary Email Address', 'Extension', 'Is SMS',
            'PHONENUMBERCOREFIELDS.isUnlisted', 'Contact Phone Number ID', 'phoneNumberAsEntered', 'Phone Type', 'Phone Number Priority Order',
            'Is Preferred', 'Street', 'Line Two', 'Unit', 'City', 'State', 'Postal Code', 'Geocode Latitude', 'Geocode Longitude',
            'PERSONADDRESSCOREFIELDS.addressVerification', 'PERSONADDRESSCOREFIELDS.county', 'PERSONADDRESSCOREFIELDS.isAddressVerified',
            'PERSONADDRESSCOREFIELDS.line3', 'Contact Address ID', 'Address Type', 'Address Priority Order', 'Address Start Date', 'Address End Date',
            '* NOT MAPPED *', 'studentNumber', 'Contact Priority Order', 'Student Contact ID', 'Student Contact Detail ID', 'Relationship Type',
            'Original Contact Type', 'Relationship Note', 'Relationship Start Date', 'Relationship End Date',
            'STUDENTCONTACTASSOCCOREFIELDS.legalGuardian', 'Contact Has Custody', 'Contact Lives With', 'Contact Allow School Pickup',
            'Is Emergency Contact', 'Contact Receives Mailings', 'STUDENTCONTACTDETAILCOREFIELDS.classroomParticipation',
            'STUDENTCONTACTDETAILCOREFIELDS.isCaregiver', 'STUDENTCONTACTDETAILCOREFIELDS.isVolunteer'
        )

        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($contact in $Data.Contacts) {
            if ($contact.ExcludeFromExport) {
                continue
            }
            if ([string]::IsNullOrWhiteSpace($contact.ContactIdentifier) -and [string]::IsNullOrWhiteSpace($contact.ContactID)) {
                throw "Contact '$($contact.FirstName) $($contact.LastName)' has neither ContactIdentifier nor ContactID."
            }

            $emails = @($Data.EmailAddresses | Where-Object { -not $_.ExcludeFromExport -and $_.ContactIdentifier -eq $contact.ContactIdentifier })
            $phones = @($Data.PhoneNumbers | Where-Object { -not $_.ExcludeFromExport -and $_.ContactIdentifier -eq $contact.ContactIdentifier } | Sort-Object PriorityOrder)
            $addresses = @($Data.Addresses | Where-Object { -not $_.ExcludeFromExport -and $_.ContactIdentifier -eq $contact.ContactIdentifier } | Sort-Object PriorityOrder)
            $relationships = @($Data.Relationships | Where-Object { -not $_.ExcludeFromExport -and $_.ContactIdentifier -eq $contact.ContactIdentifier } | Sort-Object ContactPriorityOrder, StudentNumber)
            $rowCount = [Math]::Max(1, [Math]::Max($emails.Count, [Math]::Max($phones.Count, [Math]::Max($addresses.Count, $relationships.Count))))

            for ($index = 0; $index -lt $rowCount; $index++) {
                $email = if ($index -lt $emails.Count) { $emails[$index] } else { $null }
                $phone = if ($index -lt $phones.Count) { $phones[$index] } else { $null }
                $address = if ($index -lt $addresses.Count) { $addresses[$index] } else { $null }
                $relationship = if ($index -lt $relationships.Count) { $relationships[$index] } else { $null }
                $values = [ordered]@{}
                foreach ($fieldName in $fieldNames) {
                    $values[$fieldName] = ''
                }

                $values['New Contact Identifier'] = $contact.ContactIdentifier
                $values['Contact ID'] = $contact.ContactID
                if ($index -eq 0) {
                    $values['Prefix'] = $contact.Prefix
                    $values['First Name'] = $contact.FirstName
                    $values['Middle Name'] = $contact.MiddleName
                    $values['Last Name'] = $contact.LastName
                    $values['Suffix'] = $contact.Suffix
                    $values['Gender'] = $contact.Gender
                    $values['Employer'] = $contact.Employer
                    $values['Is Active'] = [int]$contact.IsActive
                    $values['State Contact ID'] = $contact.ContactIdentifier
                }
                if ($null -ne $email) {
                    $values['Email Address'] = $email.EmailAddress
                    $values['Contact Email Address ID'] = $email.EmailAddressID
                    $values['Email Type'] = 'Current'
                    $values['Is Primary Email Address'] = [int]$email.IsPrimary
                }
                if ($null -ne $phone) {
                    $values['Contact Phone Number ID'] = $phone.PhoneNumberID
                    $values['phoneNumberAsEntered'] = $phone.PhoneNumber
                    $values['Phone Type'] = $phone.PhoneType
                    $values['Phone Number Priority Order'] = if ($phone.PriorityOrder -gt 0) { $phone.PriorityOrder } else { '' }
                    $values['Is SMS'] = [int]$phone.IsSMS
                    $values['Is Preferred'] = [int]$phone.IsPreferred
                }
                if ($null -ne $address) {
                    $values['Street'] = $address.Street
                    $values['Line Two'] = $address.LineTwo
                    $values['Unit'] = $address.Unit
                    $values['City'] = $address.City
                    $values['State'] = $address.State
                    $values['Postal Code'] = $address.PostalCode
                    $values['Contact Address ID'] = $address.AddressID
                    $values['Address Type'] = $address.AddressType
                    $values['Address Priority Order'] = if ($address.PriorityOrder -gt 0) { $address.PriorityOrder } else { '' }
                }
                if ($null -ne $relationship) {
                    $values['* NOT MAPPED *'] = $relationship.StudentName
                    $values['studentNumber'] = $relationship.StudentNumber
                    $values['Contact Priority Order'] = if ($relationship.ContactPriorityOrder -gt 0) { $relationship.ContactPriorityOrder } else { '' }
                    $values['Student Contact ID'] = $relationship.StudentContactID
                    $values['Student Contact Detail ID'] = $relationship.StudentContactDetailID
                    $values['Relationship Type'] = $relationship.RelationshipType
                    $values['Original Contact Type'] = $relationship.RelationshipType
                    $values['Relationship Note'] = $relationship.RelationshipNote
                    $values['STUDENTCONTACTASSOCCOREFIELDS.legalGuardian'] = [int]$relationship.IsLegalGuardian
                    $values['Contact Has Custody'] = [int]$relationship.HasCustody
                    $values['Contact Lives With'] = [int]$relationship.LivesWith
                    $values['Contact Allow School Pickup'] = [int]$relationship.AllowSchoolPickup
                    $values['Is Emergency Contact'] = [int]$relationship.IsEmergencyContact
                    $values['Contact Receives Mailings'] = [int]$relationship.ReceivesMail
                }

                $rows.Add([PSCustomObject]$values)
            }
        }

        if ($PSCmdlet.ShouldProcess($outputPath, "Export $($rows.Count) PowerSchool contact import rows as $outputFormat")) {
            if ($rows.Count -gt 0) {
                $rows | Export-Csv -LiteralPath $outputPath -Delimiter $delimiter -NoTypeInformation -Encoding utf8 -UseQuotes AsNeeded
            }
            else {
                $headerValues = [ordered]@{}
                foreach ($fieldName in $fieldNames) {
                    $headerValues[$fieldName] = ''
                }
                $header = [PSCustomObject]$headerValues | ConvertTo-Csv -Delimiter $delimiter -NoTypeInformation -UseQuotes AsNeeded | Select-Object -First 1
                Set-Content -LiteralPath $outputPath -Value $header -Encoding utf8
            }

            Write-Verbose "Exported $($rows.Count) rows to $outputPath"
            return Get-Item -LiteralPath $outputPath
        }
    }
}