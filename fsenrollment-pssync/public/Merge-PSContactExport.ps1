#Requires -Version 7.0

<#
.SYNOPSIS
Enriches normalized contacts with PowerSchool-generated contact IDs.

.DESCRIPTION
Matches each PSContact.ContactIdentifier to PERSON.STATECONTACTID in a
PowerSchool Person export and assigns PERSON.ID to PSContact.ContactID. The
enriched data can then be exported again with Export-PSContactImportFile for
updates to contacts created by an earlier import.

Duplicate state contact IDs, missing PowerSchool IDs, and conflicting existing
contact IDs are rejected to prevent an update from targeting the wrong person.

.PARAMETER Data
Normalized contact data to enrich. The object is updated and returned.

.PARAMETER Path
Path to a PowerSchool Person export CSV.

.PARAMETER StateContactIdColumn
Column containing the imported state contact identifier. Defaults to
PERSON.STATECONTACTID.

.PARAMETER ContactIdColumn
Column containing PowerSchool's generated contact ID. Defaults to PERSON.ID.

.PARAMETER RequireAllMatches
Throws when any normalized contact is absent from the PowerSchool export.

.EXAMPLE
$contacts = Import-FSCsv `
    -Path './data/incoming/custom_students.csv' `
    -TemplateName 'custom_csv_import_1_contacts'

$contacts = Merge-PSContactExport `
    -Data $contacts `
    -Path './data/incoming/Person_export.csv' `
    -RequireAllMatches

Export-PSContactImportFile -Data $contacts -Path './data/incoming/contacts_update.csv'

.INPUTS
PSNormalizedData

.OUTPUTS
PSNormalizedData
#>
function Merge-PSContactExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSNormalizedData]$Data,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string]$Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$StateContactIdColumn = 'PERSON.STATECONTACTID',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ContactIdColumn = 'PERSON.ID',

        [Parameter()]
        [switch]$RequireAllMatches
    )

    process {
        $powerSchoolContacts = @(Import-Csv -LiteralPath $Path)
        if ($powerSchoolContacts.Count -eq 0) {
            throw "PowerSchool contact export contains no data rows: $Path"
        }

        $columns = @($powerSchoolContacts[0].PSObject.Properties.Name)
        foreach ($requiredColumn in @($StateContactIdColumn, $ContactIdColumn)) {
            if ($columns -notcontains $requiredColumn) {
                throw "PowerSchool contact export is missing required column '$requiredColumn'."
            }
        }

        $contactIdByStateId = @{}
        foreach ($row in $powerSchoolContacts) {
            $stateContactId = ([string]$row.$StateContactIdColumn).Trim()
            if ([string]::IsNullOrWhiteSpace($stateContactId)) {
                continue
            }

            $contactId = ([string]$row.$ContactIdColumn).Trim()
            if ([string]::IsNullOrWhiteSpace($contactId)) {
                throw "PowerSchool contact '$stateContactId' has no value in '$ContactIdColumn'."
            }
            if ($contactIdByStateId.ContainsKey($stateContactId)) {
                throw "PowerSchool contact export contains duplicate '$StateContactIdColumn' value '$stateContactId'."
            }

            $contactIdByStateId[$stateContactId] = $contactId
        }

        $matchedCount = 0
        $unmatchedIdentifiers = [System.Collections.Generic.List[string]]::new()
        foreach ($contact in $Data.Contacts) {
            $contactIdentifier = ([string]$contact.ContactIdentifier).Trim()
            if (-not $contactIdentifier -or -not $contactIdByStateId.ContainsKey($contactIdentifier)) {
                $unmatchedIdentifiers.Add($contactIdentifier)
                continue
            }

            $powerSchoolContactId = $contactIdByStateId[$contactIdentifier]
            if ($contact.ContactID -and $contact.ContactID -ne $powerSchoolContactId) {
                throw "Contact '$contactIdentifier' already has ContactID '$($contact.ContactID)', which conflicts with PowerSchool ID '$powerSchoolContactId'."
            }

            $contact.ContactID = $powerSchoolContactId
            $matchedCount++
        }

        if ($unmatchedIdentifiers.Count -gt 0) {
            $message = "$($unmatchedIdentifiers.Count) of $($Data.Contacts.Count) contacts were not found by '$StateContactIdColumn'."
            if ($RequireAllMatches) {
                throw $message
            }
            Write-Warning $message
        }

        Write-Verbose "Enriched $matchedCount of $($Data.Contacts.Count) contacts with PowerSchool IDs."
        return $Data
    }
}