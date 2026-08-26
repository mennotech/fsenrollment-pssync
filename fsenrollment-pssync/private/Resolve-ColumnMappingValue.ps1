#Requires -Version 7.0

function Resolve-ColumnMappingValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CsvRow,

        [Parameter(Mandatory = $true)]
        [hashtable]$Mapping,

        [Parameter(Mandatory = $false)]
        [hashtable]$MappingContext = @{}
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
        'CoalesceColumnGroups' {
            foreach ($columnGroup in $Mapping.ColumnGroups) {
                $values = @($columnGroup | ForEach-Object { ([string]$CsvRow.$_).Trim() } | Where-Object { $_ })
                if ($values.Count -gt 0) {
                    return ($values -join [string]$Mapping.Separator)
                }
            }
            return ''
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
            $mappingName = [string]($Mapping.EntityProperty ?? $Mapping.CustomField)
            return Join-ColumnMappingParts -CsvRow $CsvRow -Parts $Mapping.Parts -MappingName $mappingName -MappingContext $MappingContext
        }
        'NormalizeEmpty' {
            $trimmedValue = ([string]$sourceValue).Trim()
            if ([string]::IsNullOrWhiteSpace($trimmedValue) -or $Mapping.EmptyValues -contains $trimmedValue) {
                return ''
            }
            return $trimmedValue
        }
        'NormalizePostalCode' {
            $format = if ($Mapping.Format) { [string]$Mapping.Format } else { 'Spaced' }
            $onInvalid = if ($Mapping.OnInvalid) { [string]$Mapping.OnInvalid } else { 'Keep' }
            $postalCode = if ($Mapping.Columns) {
                $Mapping.Columns |
                    ForEach-Object { ([string]$CsvRow.$_).Trim() } |
                    Where-Object { $_ } |
                    Select-Object -First 1
            } else {
                $sourceValue
            }
            return ConvertTo-NormalizedPostalCode -Value $postalCode -Format $format -OnInvalid $onInvalid
        }
        'NormalizeStateProv' {
            $format = if ($Mapping.Format) { [string]$Mapping.Format } else { 'Abbreviation' }
            $onInvalid = if ($Mapping.OnInvalid) { [string]$Mapping.OnInvalid } else { 'Keep' }
            $countries = if ($Mapping.Countries) { @($Mapping.Countries) } else { @('CA', 'US') }
            $stateProvince = if ($Mapping.Columns) {
                $Mapping.Columns |
                    ForEach-Object { ([string]$CsvRow.$_).Trim() } |
                    Where-Object { $_ } |
                    Select-Object -First 1
            } else {
                $sourceValue
            }
            return ConvertTo-NormalizedStateProvince -Value $stateProvince -Countries $countries -Format $format -OnInvalid $onInvalid
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

function ConvertTo-NormalizedPostalCode {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Spaced', 'Compact')]
        [string]$Format,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Truncate', 'Keep', 'Skip')]
        [string]$OnInvalid
    )

    $originalValue = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($originalValue)) {
        return ''
    }

    $compactValue = ($originalValue -replace '[^a-zA-Z0-9]', '').ToUpperInvariant()
    $isValid = $compactValue -match '^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTVWXYZ][0-9][ABCEGHJ-NPRSTVWXYZ][0-9]$'
    if (-not $isValid) {
        switch ($OnInvalid) {
            'Keep' { return $originalValue }
            'Skip' { return '' }
            'Truncate' {
                $compactValue = $compactValue.Substring(0, [Math]::Min(6, $compactValue.Length))
            }
        }
    }

    if ($Format -eq 'Spaced' -and $compactValue.Length -gt 3) {
        return "$($compactValue.Substring(0, 3)) $($compactValue.Substring(3))"
    }
    return $compactValue
}

function ConvertTo-NormalizedStateProvince {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string[]]$Countries,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Abbreviation', 'FullName')]
        [string]$Format,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Keep', 'Skip', 'Throw')]
        [string]$OnInvalid
    )

    $originalValue = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($originalValue)) {
        return ''
    }

    $countryAliases = @{
        'CA' = 'CA'; 'CAN' = 'CA'; 'CANADA' = 'CA'
        'US' = 'US'; 'USA' = 'US'; 'UNITEDSTATES' = 'US'; 'UNITEDSTATESOFAMERICA' = 'US'
    }
    $definitions = @{
        'CA' = @(
            'AB|Alberta', 'BC|British Columbia', 'MB|Manitoba', 'NB|New Brunswick',
            'NL|Newfoundland and Labrador', 'NS|Nova Scotia', 'NT|Northwest Territories',
            'NU|Nunavut', 'ON|Ontario', 'PE|Prince Edward Island', 'QC|Quebec',
            'SK|Saskatchewan', 'YT|Yukon'
        )
        'US' = @(
            'AL|Alabama', 'AK|Alaska', 'AZ|Arizona', 'AR|Arkansas', 'CA|California',
            'CO|Colorado', 'CT|Connecticut', 'DE|Delaware', 'DC|District of Columbia',
            'FL|Florida', 'GA|Georgia', 'HI|Hawaii', 'ID|Idaho', 'IL|Illinois',
            'IN|Indiana', 'IA|Iowa', 'KS|Kansas', 'KY|Kentucky', 'LA|Louisiana',
            'ME|Maine', 'MD|Maryland', 'MA|Massachusetts', 'MI|Michigan', 'MN|Minnesota',
            'MS|Mississippi', 'MO|Missouri', 'MT|Montana', 'NE|Nebraska', 'NV|Nevada',
            'NH|New Hampshire', 'NJ|New Jersey', 'NM|New Mexico', 'NY|New York',
            'NC|North Carolina', 'ND|North Dakota', 'OH|Ohio', 'OK|Oklahoma',
            'OR|Oregon', 'PA|Pennsylvania', 'RI|Rhode Island', 'SC|South Carolina',
            'SD|South Dakota', 'TN|Tennessee', 'TX|Texas', 'UT|Utah', 'VT|Vermont',
            'VA|Virginia', 'WA|Washington', 'WV|West Virginia', 'WI|Wisconsin', 'WY|Wyoming'
        )
    }

    $allowedCountries = foreach ($country in $Countries) {
        $countryKey = ([string]$country -replace '[^a-zA-Z]', '').ToUpperInvariant()
        if (-not $countryAliases.ContainsKey($countryKey)) {
            throw "NormalizeStateProv does not support country '$country'."
        }
        $countryAliases[$countryKey]
    }

    $lookupKey = ($originalValue -replace '[^a-zA-Z0-9]', '').ToUpperInvariant()
    foreach ($country in @($allowedCountries | Select-Object -Unique)) {
        foreach ($definition in $definitions[$country]) {
            $abbreviation, $fullName = $definition -split '\|', 2
            $fullNameKey = ($fullName -replace '[^a-zA-Z0-9]', '').ToUpperInvariant()
            if ($lookupKey -eq $abbreviation -or $lookupKey -eq $fullNameKey) {
                if ($Format -eq 'Abbreviation') {
                    return $abbreviation
                }
                return $fullName
            }
        }
    }

    switch ($OnInvalid) {
        'Keep' { return $originalValue }
        'Skip' { return '' }
        'Throw' { throw "State/province '$originalValue' is not valid for countries: $($allowedCountries -join ', ')." }
    }
}

function Join-ColumnMappingParts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CsvRow,

        [Parameter(Mandatory = $true)]
        [array]$Parts,

        [Parameter(Mandatory = $true)]
        [string]$MappingName,

        [Parameter(Mandatory = $false)]
        [hashtable]$MappingContext = @{}
    )

    $values = [System.Collections.Generic.List[string]]::new()
    foreach ($part in $Parts) {
        if ($part.ContainsKey('Literal')) {
            $values.Add([string]$part.Literal)
            continue
        }

        if ($part.ContainsKey('Sequence')) {
            $width = [int]$part.Sequence.Width
            if ($width -lt 1) {
                throw 'ComposeString Sequence Width must be at least 1.'
            }
            $start = if ($part.Sequence.ContainsKey('Start')) { [int]$part.Sequence.Start } else { 1 }
            if ($start -lt 0) {
                throw 'ComposeString Sequence Start cannot be negative.'
            }

            if (-not $MappingContext.ContainsKey('Sequences')) {
                $MappingContext.Sequences = @{}
            }
            $sequenceKey = "$MappingName|$($values -join '')"
            $sequence = if ($MappingContext.Sequences.ContainsKey($sequenceKey)) {
                [int]$MappingContext.Sequences[$sequenceKey] + 1
            } else {
                $start
            }
            if ($sequence -ge [Math]::Pow(10, $width)) {
                throw "ComposeString sequence '$sequenceKey' exceeds its width of $width digits."
            }
            $MappingContext.Sequences[$sequenceKey] = $sequence
            $values.Add($sequence.ToString("D$width", [System.Globalization.CultureInfo]::InvariantCulture))
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
            if ($null -eq $operation) {
                continue
            }
            $value = Invoke-ColumnMappingStringOperation -Value $value -Operation $operation
        }
        $values.Add([string]$value)
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

