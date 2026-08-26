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

.PARAMETER OutputMapName
    Maintained PowerSchool output map in config/powerschool-maps. Defaults to
    the Student Contacts Data Import Manager format.

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
        [string]$Format,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [string]$OutputMapName = 'ContactsDataImportManager'
    )

    process {
        $configRoot = Join-Path $script:ModuleRoot '..'
        $outputMapPath = Join-Path $configRoot "config/powerschool-maps/$OutputMapName.psd1"
        if (-not (Test-Path -LiteralPath $outputMapPath -PathType Leaf)) {
            throw "PowerSchool output map not found: $outputMapPath"
        }

        $outputMap = Import-PowerShellDataFile -Path $outputMapPath
        $outputMappings = @($outputMap.Mappings)
        if ($outputMappings.Count -eq 0) {
            throw "PowerSchool output map '$OutputMapName' does not define Mappings."
        }

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
                foreach ($mapping in $outputMappings) {
                    $entity = switch ($mapping.EntityType) {
                        'Contact' { $contact }
                        'EmailAddress' { $email }
                        'PhoneNumber' { $phone }
                        'Address' { $address }
                        'Relationship' { $relationship }
                        default { $null }
                    }

                    $value = $null
                    if (-not ($mapping.FirstRowOnly -and $index -ne 0) -and ($null -ne $entity -or -not $mapping.EntityType)) {
                        if ($mapping.ContainsKey('Value')) {
                            $value = $mapping.Value
                        }
                        elseif ($entity -and $mapping.EntityProperty) {
                            $value = $entity.($mapping.EntityProperty)
                        }

                        switch ($mapping.Transform) {
                            'BooleanInt' { $value = if ($null -eq $value) { '' } else { [int][bool]$value } }
                            'PositiveInt' { $value = if ([int]$value -gt 0) { [int]$value } else { '' } }
                        }
                    }

                    $values[$mapping.OutputColumn] = if ($null -eq $value) { '' } else { $value }
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
                foreach ($mapping in $outputMappings) {
                    $headerValues[$mapping.OutputColumn] = ''
                }
                $header = [PSCustomObject]$headerValues | ConvertTo-Csv -Delimiter $delimiter -NoTypeInformation -UseQuotes AsNeeded | Select-Object -First 1
                Set-Content -LiteralPath $outputPath -Value $header -Encoding utf8
            }

            Write-Verbose "Exported $($rows.Count) rows to $outputPath"
            return Get-Item -LiteralPath $outputPath
        }
    }
}