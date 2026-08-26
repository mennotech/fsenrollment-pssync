#Requires -Version 7.0

function Get-PowerSchoolApiMappings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $TemplateMetadata
    )

    $mapName = [string]$TemplateMetadata.PowerSchoolApiMapName

    if ($mapName) {
        if ($mapName -notmatch '^[A-Za-z0-9_-]+$') {
            throw "Invalid PowerSchool map name: $mapName"
        }
        $configRoot = Join-Path $script:ModuleRoot '..'
        $mapPath = Join-Path $configRoot "config/powerschool-maps/$mapName.psd1"
        if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
            throw "PowerSchool map not found: $mapPath"
        }

        $powerSchoolMap = Import-PowerShellDataFile -Path $mapPath
        $apiMappings = [System.Collections.Generic.List[object]]::new()
        foreach ($mapping in @($powerSchoolMap.Mappings | Where-Object PowerSchoolAPIField)) {
            $apiMappings.Add($mapping)
        }

        $apiPrefix = [string]$powerSchoolMap.CustomFieldPrefix
        if ([string]::IsNullOrWhiteSpace($apiPrefix)) {
            throw "PowerSchool API map '$mapName' does not define CustomFieldPrefix."
        }
        foreach ($customFieldName in @($TemplateMetadata.ColumnMappings.CustomField | Where-Object { $_ } | Select-Object -Unique)) {
            $apiMappings.Add(@{
                CustomField = $customFieldName
                PowerSchoolAPIField = "$apiPrefix$customFieldName"
            })
        }

        return @($apiMappings)
    }

    if ($TemplateMetadata -and $TemplateMetadata.ColumnMappings) {
        $columnMappings = $TemplateMetadata.ColumnMappings
        if ($columnMappings -is [System.Collections.IDictionary]) {
            $columnMappings = @($columnMappings.Values)
        }
        elseif ($columnMappings -is [PSCustomObject] -and -not $columnMappings.PSObject.Properties['EntityProperty']) {
            $columnMappings = @($columnMappings.PSObject.Properties.Value)
        }

        return @($columnMappings | ForEach-Object { @($_) } | Where-Object { $_.PowerSchoolAPIField })
    }

    return @()
}
