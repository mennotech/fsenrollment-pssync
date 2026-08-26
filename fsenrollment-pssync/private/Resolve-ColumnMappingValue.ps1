#Requires -Version 7.0

function Resolve-ColumnMappingValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CsvRow,

        [Parameter(Mandatory = $true)]
        [hashtable]$Mapping
    )

    $sourceValue = if ($Mapping.CSVColumn) { $CsvRow.($Mapping.CSVColumn) } else { $null }
    if (-not $Mapping.Transform) {
        if ($Mapping.ContainsKey('Value')) {
            return $Mapping.Value
        }
        return $sourceValue
    }

    switch ($Mapping.Transform) {
        'Constant' {
            return $Mapping.Value
        }
        'NamePart' {
            return Get-PersonNamePart -Name $sourceValue -Part $Mapping.Part
        }
        'PreferredName' {
            return ([string]$sourceValue).Trim()
        }
        'CoalesceColumns' {
            $value = $Mapping.Columns |
                ForEach-Object { ([string]$CsvRow.$_).Trim() } |
                Where-Object { $_ } |
                Select-Object -First 1
            return [string]$value
        }
        'GenderCode' {
            switch -Regex (([string]$sourceValue).Trim()) {
                '^(?i:f|female)$' { return 'F' }
                '^(?i:m|male)$' { return 'M' }
                default { return $sourceValue }
            }
        }
        'Lookup' {
            $key = ([string]$sourceValue).Trim()
            if ($Mapping.Map.ContainsKey($key)) {
                return $Mapping.Map[$key]
            }
            if ($Mapping.ContainsKey('DefaultValue')) {
                return $Mapping.DefaultValue
            }
            return $sourceValue
        }
        'JoinColumns' {
            $values = @($Mapping.Columns | ForEach-Object { ([string]$CsvRow.$_).Trim() } | Where-Object { $_ })
            return ($values -join [string]$Mapping.Separator)
        }
        'ComposeString' {
            return Join-ColumnMappingParts -CsvRow $CsvRow -Parts $Mapping.Parts
        }
        'NormalizeEmpty' {
            $trimmedValue = ([string]$sourceValue).Trim()
            if ([string]::IsNullOrWhiteSpace($trimmedValue) -or $Mapping.EmptyValues -contains $trimmedValue) {
                return ''
            }
            return $trimmedValue
        }
        'NonEmptyFlag' {
            $trimmedValue = ([string]$sourceValue).Trim()
            if ([string]::IsNullOrWhiteSpace($trimmedValue) -or $Mapping.EmptyValues -contains $trimmedValue) {
                return 0
            }
            return 1
        }
        default {
            throw "Unknown column mapping transform '$($Mapping.Transform)' for property '$($Mapping.EntityProperty)'."
        }
    }
}

function Join-ColumnMappingParts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CsvRow,

        [Parameter(Mandatory = $true)]
        [array]$Parts
    )

    $values = foreach ($part in $Parts) {
        if ($part.ContainsKey('Literal')) {
            [string]$part.Literal
            continue
        }

        $columns = if ($part.Column) { @($part.Column) } else { @($part.Columns) }
        if ($columns.Count -eq 0) {
            throw 'ComposeString parts must define Literal, Column, or Columns.'
        }

        $value = $columns | ForEach-Object { ([string]$CsvRow.$_).Trim() } | Where-Object { $_ } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($value)) {
            return ''
        }

        foreach ($operation in @($part.Operations)) {
            $value = Invoke-ColumnMappingStringOperation -Value $value -Operation $operation
        }
        [string]$value
    }

    return ($values -join '')
}

function Invoke-ColumnMappingStringOperation {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [object]$Operation
    )

    $operationName = if ($Operation -is [string]) { $Operation } else { $Operation.Name }
    switch ($operationName) {
        'Trim' { return $Value.Trim() }
        'Lower' { return $Value.ToLowerInvariant() }
        'Alphanumeric' { return ($Value -replace '[^a-zA-Z0-9]', '') }
        'First' {
            $count = [int]$Operation.Count
            if ($count -lt 1) { throw 'The First operation Count must be at least 1.' }
            return $Value.Substring(0, [Math]::Min($count, $Value.Length))
        }
        'Right' {
            $count = [int]$Operation.Count
            if ($count -lt 1) { throw 'The Right operation Count must be at least 1.' }
            return $Value.Substring([Math]::Max(0, $Value.Length - $count))
        }
        'GraduationYear' {
            $grade = 0
            if (-not [int]::TryParse($Value, [ref]$grade)) {
                throw "The GraduationYear operation requires a numeric grade, but received '$Value'."
            }
            $schoolYearStart = [int]$Operation.SchoolYearStart
            $finalGrade = [int]$Operation.FinalGrade
            return [string]($schoolYearStart + $finalGrade - $grade + 1)
        }
        default {
            throw "Unknown ComposeString operation '$operationName'."
        }
    }
}

function Get-PersonNamePart {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('First', 'Middle', 'Last', 'Full')]
        [string]$Part
    )

    $nameParts = @(([string]$Name -split '\s+' | Where-Object { $_ }))
    if ($nameParts.Count -eq 0) {
        return ''
    }

    switch ($Part) {
        'First' { return $nameParts[0] }
        'Last' { return $nameParts[-1] }
        'Middle' {
            if ($nameParts.Count -le 2) { return '' }
            return ($nameParts[1..($nameParts.Count - 2)] -join ' ')
        }
        'Full' { return ($nameParts -join ' ') }
    }
}

