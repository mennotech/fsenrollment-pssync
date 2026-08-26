<#
.SYNOPSIS
Creates a deterministic, anonymized example from a custom student CSV export.

.DESCRIPTION
Replaces identifying student, parent, contact, address, health, organization,
and submission values while preserving columns, row order, blanks, categorical
responses, multiline field structure, and common date and identifier formats.

.PARAMETER InputPath
Path to the source CSV file.

.PARAMETER OutputPath
Path for the anonymized example CSV.

.PARAMETER Seed
Seed used to generate deterministic example values.

.EXAMPLE
./scripts/Anonymize-CustomStudentCsv.ps1 `
    -InputPath ./data/incoming/custom-students.csv `
    -OutputPath ./data/examples/custom_csv_import_1_example.csv

.INPUTS
None.

.OUTPUTS
System.IO.FileInfo for the generated example file.

.NOTES
Requires PowerShell 7 or later.
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [int]$Seed = 20260826
)

$rows = @(Import-Csv -LiteralPath $InputPath)
if ($rows.Count -eq 0) {
    throw "The input CSV contains no data rows: $InputPath"
}

$random = [System.Random]::new($Seed)
$valueMaps = @{}
$counters = @{}
$exampleDictionary = @{
    GivenNames = @(
        'Amelia', 'Benjamin', 'Caleb', 'Clara', 'Daniel', 'Eleanor', 'Elias', 'Emma',
        'Ethan', 'Grace', 'Hannah', 'Isaac', 'Jonah', 'Julia', 'Leah', 'Levi',
        'Lucas', 'Maya', 'Naomi', 'Nathan', 'Nora', 'Oliver', 'Rachel', 'Samuel',
        'Simon', 'Sophie', 'Theo', 'Victoria', 'William', 'Zoe'
    )
    FamilyNames = @(
        'Alder', 'Bennett', 'Carver', 'Dalton', 'Ellis', 'Fletcher', 'Gibson', 'Hartwell',
        'Iverson', 'Jensen', 'Keller', 'Langford', 'Mercer', 'Nolan', 'Osborne', 'Palmer',
        'Quincy', 'Reeves', 'Sawyer', 'Turner', 'Underwood', 'Vickers', 'Walker', 'Young',
        'Zimmer', 'Brooks', 'Collins', 'Foster', 'Morrison', 'Sullivan'
    )
    Cities = @(
        'Aspen Crossing', 'Birch Harbour', 'Cedar Glen', 'Clearwater Bend',
        'Elm Prairie', 'Fairview Ridge', 'Golden Fields', 'Lake Briar',
        'Maple Crossing', 'North Willow', 'Oak Valley', 'Pinehaven',
        'Prairie Junction', 'Riverstone', 'Silver Creek'
    )
    Streets = @(
        'Aspen Grove', 'Birchwood Drive', 'Cedar Lane', 'Clearwater Road',
        'Cottonwood Crescent', 'Elm Street', 'Fairview Avenue', 'Harvest Lane',
        'Lakeview Drive', 'Maple Bay', 'Meadowlark Road', 'Oak Ridge',
        'Parkland Way', 'Pinecrest Avenue', 'Prairie Trail', 'Riverbend Road',
        'Silverleaf Crescent', 'Spruce Street', 'Sunrise Bay', 'Willow Lane'
    )
    Churches = @(
        'Cedar Grove Community Church', 'Clearwater Fellowship', 'Elm Prairie Chapel',
        'Gracefield Church', 'Harvest Community Fellowship', 'Lakeview Community Church',
        'North Willow Chapel', 'Prairie Hope Church', 'Riverstone Fellowship', 'Westfield Church'
    )
    Denominations = @(
        'Anabaptist', 'Baptist', 'Christian Reformed', 'Evangelical Free', 'Lutheran',
        'Mennonite', 'Mennonite Brethren', 'Non-denominational', 'Pentecostal', 'United'
    )
    Schools = @(
        'Aspen Ridge School', 'Cedar Glen Academy', 'Clearwater Elementary',
        'Elm Prairie School', 'Lake Briar Collegiate', 'Maple Crossing School',
        'North Willow Academy', 'Pinehaven School', 'Prairie Junction Collegiate',
        'Riverstone Community School'
    )
    SchoolDivisions = @(
        'Aspen Valley School Division', 'Clearwater Plains School Division',
        'Lake Country School Division', 'Prairie West School Division',
        'Riverbend School Division'
    )
    Workplaces = @(
        'Aspen Valley Foods', 'Cedar Works Cooperative', 'Clearwater Health Centre',
        'Elm Prairie Hardware', 'Fairview Accounting', 'Golden Fields Farms',
        'Lake Briar Library', 'Maple Crossing Market', 'North Willow Dental',
        'Parkland Construction', 'Prairie Junction Credit Union', 'Riverstone Pharmacy'
    )
    Notes = @(
        'Receives reading support twice weekly',
        'Benefits from written instructions and additional processing time',
        'Uses an individualized classroom support plan',
        'Requires access to prescribed medication during school hours',
        'Has a documented food allergy and carries emergency medication',
        'Meets periodically with the school support team'
    )
}

function Get-MappedValue {
    param(
        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Original,

        [Parameter(Mandatory)]
        [scriptblock]$Factory
    )

    if (-not $valueMaps.ContainsKey($Category)) {
        $valueMaps[$Category] = @{}
        $counters[$Category] = 0
    }

    if (-not $valueMaps[$Category].ContainsKey($Original)) {
        $counters[$Category]++
        $valueMaps[$Category][$Original] = & $Factory $counters[$Category]
    }

    return $valueMaps[$Category][$Original]
}

function Get-DictionaryValue {
    param(
        [Parameter(Mandatory)][object[]]$Values,
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][string]$Original
    )

    for ($offset = 0; $offset -lt $Values.Count; $offset++) {
        $candidate = [string]$Values[(($Number - 1 + $offset) % $Values.Count)]
        if ($candidate -cne $Original) {
            return $candidate
        }
    }

    throw 'The example dictionary does not contain a value different from the source value.'
}

function Convert-DigitsLike {
    param([Parameter(Mandatory)][string]$Value)

    return -join $Value.ToCharArray().ForEach({
        if ([char]::IsDigit($_)) {
            [char]([int][char]'0' + (([int][char]$_ - [int][char]'0' + 7) % 10))
        } else {
            $_
        }
    })
}

function Convert-PostalCodeLike {
    param([Parameter(Mandatory)][string]$Value)

    $letters = 'ABCEGHJKLMNPRSTVWXYZ'
    return -join $Value.ToCharArray().ForEach({
        if ([char]::IsDigit($_)) {
            [char]([int][char]'0' + (([int][char]$_ - [int][char]'0' + 7) % 10))
        } elseif ([char]::IsLetter($_)) {
            $index = $letters.IndexOf([char]::ToUpperInvariant($_))
            $replacement = $letters[($index + 7) % $letters.Length]
            if ([char]::IsLower($_)) { [char]::ToLowerInvariant($replacement) } else { $replacement }
        } else {
            $_
        }
    })
}

function Convert-DateLike {
    param(
        [Parameter(Mandatory)][string]$Value,
        [datetime]$Replacement = [datetime]::new(2026, 8, 26, 14, 15, 0)
    )

    $format = switch -Regex ($Value) {
        '^\d{4}-\d{2}-\d{2}T' { 'yyyy-MM-ddTHH:mm:ss'; break }
        '^\d{4}-\d{2}-\d{2} ' { 'yyyy-MM-dd HH:mm:ss'; break }
        '^\d{4}-\d{2}-\d{2}$' { 'yyyy-MM-dd'; break }
        '^\d{1,2}-[A-Za-z]{3}-\d{2}$' { 'dd-MMM-yy'; break }
        '^[A-Za-z]{3} \d{1,2}, \d{4} \d{1,2}:\d{2}' { 'MMM d, yyyy h:mm:ss tt'; break }
        '^[A-Za-z]{3} \d{1,2}, \d{4}$' { 'MMM d, yyyy'; break }
        '^\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}' { 'M/d/yyyy h:mm:ss tt'; break }
        '^\d{1,2}/\d{1,2}/\d{4}$' { 'M/d/yyyy'; break }
        default { 'yyyy-MM-dd' }
    }

    return $Replacement.ToString($format, [Globalization.CultureInfo]::InvariantCulture)
}

function Convert-MultilineText {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Label
    )

    $separator = if ($Value.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lineCount = [regex]::Split($Value, '\r?\n').Count
    return (1..$lineCount).ForEach({ "$Label line $_" }) -join $separator
}

foreach ($rowIndex in 0..($rows.Count - 1)) {
    $row = $rows[$rowIndex]
    foreach ($property in $row.PSObject.Properties) {
        $column = $property.Name
        $value = [string]$property.Value
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        $replacement = switch -Regex ($column) {
            '^(First Name|Student''s Preferred Name.*|Father.s Given Name|Mother.s Given Name)$' {
                Get-MappedValue -Category 'GivenName' -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.GivenNames -Number $number -Original $value
                }
                break
            }
            '^(Middle Name\(s\)|Father.s Surname|Mother.s Surname|Last Name)$' {
                Get-MappedValue -Category 'FamilyName' -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.FamilyNames -Number $number -Original $value
                }
                break
            }
            '^(Emergency Contact Name:|Name of Parent)$' {
                Get-MappedValue -Category 'FullName' -Original $value -Factory {
                    param($number)
                    $givenName = $exampleDictionary.GivenNames[(($number * 3) % $exampleDictionary.GivenNames.Count)]
                    $familyName = $exampleDictionary.FamilyNames[(($number * 7) % $exampleDictionary.FamilyNames.Count)]
                    "$givenName $familyName"
                }
                break
            }
            'Birth Date' {
                $grade = 0
                [void][int]::TryParse([string]$row.'Applying For Grade', [ref]$grade)
                $birthYear = 2020 - $grade - $random.Next(0, 2)
                $birthDate = [datetime]::new($birthYear, $random.Next(1, 13), $random.Next(1, 28))
                Convert-DateLike -Value $value -Replacement $birthDate
                break
            }
            '^(Entry_Dates|Last Update Date)$' {
                Convert-DateLike -Value $value -Replacement ([datetime]::new(2026, 8, 26, 14, 15, 0).AddMinutes($rowIndex))
                break
            }
            'Email' {
                $givenName = $exampleDictionary.GivenNames[$rowIndex % $exampleDictionary.GivenNames.Count].ToLowerInvariant()
                $familyName = $exampleDictionary.FamilyNames[($rowIndex * 3) % $exampleDictionary.FamilyNames.Count].ToLowerInvariant()
                "$givenName.$familyName@prairiemail.example"
                break
            }
            '(Phone:?|Number)$' {
                Convert-DigitsLike -Value $value
                break
            }
            '(Postal / Zip Code|Postal Code)$' {
                Convert-PostalCodeLike -Value $value
                break
            }
            'Street Address' {
                if ($column -match 'Line 2') {
                    "Unit $($rowIndex + 2)"
                } else {
                    $street = $exampleDictionary.Streets[$rowIndex % $exampleDictionary.Streets.Count]
                    "$($rowIndex + 101) $street"
                }
                break
            }
            'City$' {
                Get-MappedValue -Category 'City' -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.Cities -Number $number -Original $value
                }
                break
            }
            '^MB Health #' {
                Convert-DigitsLike -Value $value
                break
            }
            '^Submission IP$' {
                "192.0.2.$($rowIndex + 1)"
                break
            }
            '^Submission ID$' {
                Convert-DigitsLike -Value $value
                break
            }
            '^Church Attending$' {
                Get-MappedValue -Category $column -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.Churches -Number $number -Original $value
                }
                break
            }
            '^Denomination$' {
                Get-MappedValue -Category $column -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.Denominations -Number $number -Original $value
                }
                break
            }
            '^Name of the last Manitoba school attended$' {
                Get-MappedValue -Category $column -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.Schools -Number $number -Original $value
                }
                break
            }
            '^Name of the school division$' {
                Get-MappedValue -Category $column -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.SchoolDivisions -Number $number -Original $value
                }
                break
            }
            '^(Father.s Workplace|Mother.s Workplace)$' {
                Get-MappedValue -Category $column -Original $value -Factory {
                    param($number)
                    Get-DictionaryValue -Values $exampleDictionary.Workplaces -Number $number -Original $value
                }
                break
            }
            '^(Allergies:|Medical Restrictions & Medications:|Academic Support|Diagnosis/Assessments|Psychological Support|Custody Description - Other|Student Lives With - Other|Student.s Parents - Other)$' {
                if ($value -match '^(?i:none|n/?a|none known|no know(?:n)? allergies)$') {
                    $value
                } else {
                    $note = $exampleDictionary.Notes[$rowIndex % $exampleDictionary.Notes.Count]
                    Convert-MultilineText -Value $value -Label $note
                }
                break
            }
            default {
                $value
            }
        }

        $property.Value = $replacement
    }
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -UseQuotes AsNeeded -Encoding utf8BOM
Get-Item -LiteralPath $OutputPath