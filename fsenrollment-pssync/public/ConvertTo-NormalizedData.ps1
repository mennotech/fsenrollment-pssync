#Requires -Version 7.0

<#
.SYNOPSIS
    Converts CSV data to normalized PowerSchool API format.

.DESCRIPTION
    Takes raw CSV data and normalizes it to match PowerSchool API field names
    and data structures using a specified normalization template. Handles field
    mapping, data type conversion, and validation.

.PARAMETER CsvData
    The CSV data to normalize. Can be an array of PSCustomObject from Import-Csv.

.PARAMETER DataType
    The type of data being normalized (e.g., 'students', 'parents', 'staff').
    Must match a supported type in the normalization template.

.PARAMETER Template
    The normalization template hashtable. If not provided, loads the default
    'fs_powerschool_nonapi_report' template.

.PARAMETER TemplateName
    The name of the template to load if Template parameter is not provided.
    Default is 'fs_powerschool_nonapi_report'.

.PARAMETER SkipValidation
    If specified, skips validation of required fields.

.OUTPUTS
    System.Array
    Returns an array of normalized objects ready for PowerSchool API.

.EXAMPLE
    $students = Import-Csv './data/students.csv'
    $normalized = ConvertTo-NormalizedData -CsvData $students -DataType 'students'
    Normalizes student CSV data using the default template.

.EXAMPLE
    $parents = Import-Csv './data/parents.csv'
    $template = Get-CsvNormalizationTemplate -TemplateName 'custom_format'
    $normalized = ConvertTo-NormalizedData -CsvData $parents -DataType 'parents' -Template $template
    Normalizes parent data using a custom template.

.EXAMPLE
    $staff = Import-Csv './data/staff.csv'
    $normalized = ConvertTo-NormalizedData -CsvData $staff -DataType 'staff' -SkipValidation
    Normalizes staff data without validation.

.NOTES
    The function maps CSV column names to PowerSchool API field names, converts
    data types, and validates required fields based on the template configuration.
#>
function ConvertTo-NormalizedData {
    [CmdletBinding()]
    [OutputType([System.Array])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSCustomObject[]]$CsvData,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('students', 'parents', 'staff', 'courses', 'enrollments')]
        [string]$DataType,

        [Parameter(Mandatory = $false)]
        [hashtable]$Template,

        [Parameter(Mandatory = $false)]
        [string]$TemplateName = 'fs_powerschool_nonapi_report',

        [Parameter(Mandatory = $false)]
        [switch]$SkipValidation
    )

    begin {
        Write-Verbose "Starting normalization for data type: $DataType"

        if (-not $Template) {
            Write-Verbose "Loading template: $TemplateName"
            $Template = Get-CsvNormalizationTemplate -TemplateName $TemplateName
        }

        $dataTypeCapitalized = $DataType.Substring(0, 1).ToUpper() + $DataType.Substring(1)
        
        if (-not $Template.ContainsKey($dataTypeCapitalized)) {
            throw "Template does not contain mappings for data type: $DataType"
        }

        $fieldMappings = $Template[$dataTypeCapitalized]
        $dataTypeConfig = if ($Template.DataTypes.ContainsKey($dataTypeCapitalized)) {
            $Template.DataTypes[$dataTypeCapitalized]
        } else {
            @{}
        }

        $validationRules = if ($Template.Validation.ContainsKey($dataTypeCapitalized)) {
            $Template.Validation[$dataTypeCapitalized]
        } else {
            @{}
        }

        $transformations = if ($Template.ContainsKey('Transformations')) {
            $Template.Transformations
        } else {
            @{}
        }

        $normalizedData = [System.Collections.Generic.List[PSCustomObject]]::new()
        $validationErrors = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($row in $CsvData) {
            $normalizedRow = [ordered]@{}
            $csvColumns = $row.PSObject.Properties.Name

            foreach ($apiField in $fieldMappings.Keys) {
                $possibleColumns = $fieldMappings[$apiField]
                $value = $null

                foreach ($column in $possibleColumns) {
                    $matchedColumn = $csvColumns | Where-Object { $_ -eq $column } | Select-Object -First 1
                    if ($matchedColumn) {
                        $value = $row.$matchedColumn
                        break
                    }
                }

                if ($null -ne $value -and $value -ne '') {
                    $convertedValue = ConvertDataType -Value $value -TargetType ($dataTypeConfig[$apiField]) -Transformations $transformations
                    $normalizedRow[$apiField] = $convertedValue
                }
                else {
                    $normalizedRow[$apiField] = $null
                }
            }

            $normalizedObject = [PSCustomObject]$normalizedRow

            if (-not $SkipValidation -and $validationRules.ContainsKey('RequiredFields')) {
                $missingFields = @()
                foreach ($requiredField in $validationRules.RequiredFields) {
                    if ([string]::IsNullOrWhiteSpace($normalizedObject.$requiredField)) {
                        $missingFields += $requiredField
                    }
                }

                if ($missingFields.Count -gt 0) {
                    $errorMsg = "Row missing required fields: $($missingFields -join ', ')"
                    $validationErrors.Add($errorMsg)
                    Write-Warning $errorMsg
                }
            }

            $normalizedData.Add($normalizedObject)
        }
    }

    end {
        if ($validationErrors.Count -gt 0 -and -not $SkipValidation) {
            Write-Warning "Normalization completed with $($validationErrors.Count) validation error(s)"
        }

        Write-Verbose "Normalized $($normalizedData.Count) records"
        return $normalizedData.ToArray()
    }
}

<#
.SYNOPSIS
    Helper function to convert data types.

.DESCRIPTION
    Internal helper function that converts string values from CSV to appropriate
    data types based on template configuration.

.PARAMETER Value
    The value to convert.

.PARAMETER TargetType
    The target data type (e.g., 'int', 'bool', 'date').

.PARAMETER Transformations
    Hashtable containing transformation rules from the template.

.OUTPUTS
    System.Object
    Returns the converted value in the appropriate type.

.NOTES
    This is a private helper function used by ConvertTo-NormalizedData.
#>
function ConvertDataType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value,

        [Parameter(Mandatory = $false)]
        [string]$TargetType,

        [Parameter(Mandatory = $false)]
        [hashtable]$Transformations = @{}
    )

    if ($null -eq $Value -or $Value -eq '') {
        return $null
    }

    $stringValue = $Value.ToString().Trim()

    if ([string]::IsNullOrWhiteSpace($stringValue)) {
        return $null
    }

    switch ($TargetType) {
        'int' {
            $intValue = 0
            if ([int]::TryParse($stringValue, [ref]$intValue)) {
                return $intValue
            }
            return $null
        }
        'bool' {
            $booleanTrueValues = if ($Transformations.ContainsKey('BooleanTrue')) {
                $Transformations.BooleanTrue
            } else {
                @('1', 'true', 'yes', 'y')
            }

            $booleanFalseValues = if ($Transformations.ContainsKey('BooleanFalse')) {
                $Transformations.BooleanFalse
            } else {
                @('0', 'false', 'no', 'n', '')
            }

            if ($booleanTrueValues -contains $stringValue.ToLower()) {
                return $true
            }
            elseif ($booleanFalseValues -contains $stringValue.ToLower()) {
                return $false
            }
            return $null
        }
        'date' {
            $dateValue = Get-Date
            if ([datetime]::TryParse($stringValue, [ref]$dateValue)) {
                return $dateValue
            }
            return $null
        }
        default {
            return $stringValue
        }
    }
}
