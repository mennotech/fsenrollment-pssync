#Requires -Version 7.0

<#
.SYNOPSIS
    Exports normalized student data using a maintained PowerSchool output map.

.DESCRIPTION
    Writes PSNormalizedData students to CSV or TSV using a maintained output map.
    Output maps are independent of source import templates and can reference core
    student properties or normalized custom fields.

.PARAMETER Data
    Normalized student data.

.PARAMETER Path
    Destination path for the import file.

.PARAMETER Format
    Delimited file format. If omitted, .tsv paths use TSV and other paths use CSV.

.PARAMETER OutputMapName
    Maintained PowerSchool output map in config/powerschool-maps. Defaults to the
    Quick Import Students format.

.EXAMPLE
    $data | Export-PSStudentImportFile -Path './students.csv'

.INPUTS
    PSNormalizedData

.OUTPUTS
    System.IO.FileInfo
#>
function Export-PSStudentImportFile {
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
        [string]$OutputMapName = 'StudentsQuickImport'
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

        $customFieldNames = @($Data.TemplateMetadata.ColumnMappings.CustomField | Where-Object { $_ } | Select-Object -Unique)
        $customFieldPrefix = [string]$outputMap.CustomFieldPrefix

        $outputFormat = if ($Format) { $Format } elseif ([System.IO.Path]::GetExtension($Path) -ieq '.tsv') { 'Tsv' } else { 'Csv' }
        $delimiter = if ($outputFormat -eq 'Tsv') { "`t" } else { ',' }
        $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $outputDirectory = Split-Path -Path $outputPath -Parent
        if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
            throw "Output directory does not exist: $outputDirectory"
        }

        $rows = foreach ($student in $Data.Students) {
            $values = [ordered]@{}
            foreach ($mapping in $outputMappings) {
                $value = if ($mapping.CustomField) {
                    $student.CustomFields[$mapping.CustomField]
                }
                elseif ($mapping.EntityProperty) {
                    $student.($mapping.EntityProperty)
                }
                else {
                    $null
                }

                switch ($mapping.Transform) {
                    'LegalFullName' {
                        $value = @(
                            $student.CustomFields.legal_givenname
                            $student.CustomFields.legal_middlenames
                            $student.CustomFields.legal_surname
                        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                        $value = $value -join ' '
                    }
                    'PreferredName' {
                        $value = if ($student.FirstName -ne $student.CustomFields.legal_givenname) { $student.FirstName } else { '' }
                    }
                    'BooleanInt' {
                        $value = if ([bool]$value) { 1 } else { '' }
                    }
                }

                if ($mapping.DateTimeFormat -and $value -is [datetime] -and $value -ne [datetime]::MinValue) {
                    $value = $value.ToString($mapping.DateTimeFormat, [System.Globalization.CultureInfo]::InvariantCulture)
                }
                elseif ($value -is [datetime] -and $value -eq [datetime]::MinValue) {
                    $value = ''
                }

                $values[$mapping.OutputColumn] = if ($null -eq $value) { '' } else { $value }
            }

            if (-not [string]::IsNullOrWhiteSpace($customFieldPrefix)) {
                foreach ($customFieldName in $customFieldNames) {
                    $customValue = $student.CustomFields[$customFieldName]
                    if ($outputMap.CustomFieldBooleanFormat -eq 'Integer' -and $customValue -is [bool]) {
                        $customValue = if ($customValue) { 1 } else { '' }
                    }
                    $values["$customFieldPrefix$customFieldName"] = if ($null -eq $customValue) { '' } else { $customValue }
                }
            }

            [PSCustomObject]$values
        }

        if ($PSCmdlet.ShouldProcess($outputPath, "Export $(@($rows).Count) PowerSchool student import rows as $outputFormat")) {
            @($rows) | Export-Csv -LiteralPath $outputPath -Delimiter $delimiter -NoTypeInformation -Encoding utf8 -UseQuotes AsNeeded
            return Get-Item -LiteralPath $outputPath
        }
    }
}