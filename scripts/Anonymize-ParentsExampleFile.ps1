<#
.SYNOPSIS
Anonymize name, phone, email, street, postal code, city, and province/state columns in a CSV.

.DESCRIPTION
Reads a CSV and randomizes:
- "First Name", "Middle Name", "Last Name" (preserves blanks)
- "phoneNumberAsEntered" (preserves punctuation like hyphens; replaces only digits)
- "Email Address" (preserves domain; randomizes local part; preserves blanks)
- "Street" (preserves leading number/unit-like prefix; replaces street name and suffix with plausible values)
- "Postal Code" (preserves letter/digit/space pattern; uses valid Canadian postal letters)
 - "City" (replaces with a plausible city name; preserves blanks)
 - "State" (replaces with a plausible Canadian province/territory abbreviation; preserves blanks)
All other fields are preserved.

.PARAMETER InputPath
Path to the input CSV file.

.PARAMETER OutputPath
Path to write the anonymized CSV file.

.PARAMETER Seed
Optional seed for deterministic generation.

.EXAMPLE
./Anonymize-Names.ps1 -InputPath ./data/examples/parents_filtered.csv -OutputPath ./data/examples/parents_filtered.anonymized.csv -Verbose

.NOTES
- Cross-platform (PowerShell 7+)
- Uses only built-in cmdlets
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [int]$Seed,

    [string]$StudentCsvPath
)

#Requires -Version 7.0

begin {
    Write-Verbose "Reading input from: $InputPath"

    # Name pools (gender-neutral and mixed), expand as needed
    $FirstNames = @(
        'Alex','Avery','Blake','Cameron','Casey','Charlie','Dakota','Drew','Elliot','Emerson',
        'Finley','Frankie','Harley','Hayden','Jamie','Jesse','Jordan','Jules','Kai','Kendall',
        'Logan','Marley','Morgan','Noel','Parker','Peyton','Quinn','Reese','River','Robin',
        'Rowan','Riley','Sage','Sam','Shay','Skyler','Sloan','Taylor','Toni','West',
        'Arden','Bailey','Blair','Devin','Ellis','Hollis','Keegan','Lane','Micah','Shiloh',
        'Tatum','Tristan','Wren','Zion','Remy','Noah','Theo','Nova','Ari','Sunny'
    )

    $MiddleNames = @(
        'Lee','James','Ray','Kai','Skye','Jae','Rey','Drew','Lane','Quinn',
        'Blair','Sage','Reese','Jules','Grey','Noel','Wren','Rain','Ash','Beau',
        'Fox','Faye','True','Snow','Blue','Zoe','Max','June','Rue','Wynn'
    )

    $LastNames = @(
        'Archer','Bennett','Carter','Dawson','Ellison','Foster','Griffin','Hayes','Ingram','Jensen',
        'Keller','Lawson','Maddox','Nolan','Owens','Porter','Quincy','Ramsey','Sawyer','Tanner',
        'Ulrich','Vaughn','Walker','Xavier','Young','Zimmer','Bishop','Clark','Douglas','Edwards',
        'Franklin','Gibson','Hughes','Irwin','Jacobs','Kennedy','Larson','Mitchell','Nelson','Osborne',
        'Parker','Quinn','Reid','Stevens','Thompson','Underwood','Vance','Watson','Yates','Zimmerman'
    )

    if ($PSBoundParameters.ContainsKey('Seed')) {
        $script:Rand = [System.Random]::new($Seed)
        Write-Verbose "Using deterministic random seed: $Seed"
    } else {
        $script:Rand = [System.Random]::new()
    }

    function Get-RandItem {
        param([object[]]$Array)
        return $Array[$script:Rand.Next(0, $Array.Count)]
    }

    function ConvertTo-RandomPhoneLike {
        param(
            [Parameter(Mandatory=$true)]
            [string]$Value
        )
        # Replace digits with random digits; keep non-digits as-is (preserves hyphens/format)
        $chars = $Value.ToCharArray()
        for ($i=0; $i -lt $chars.Length; $i++) {
            if ([char]::IsDigit($chars[$i])) {
                # Use ASCII '0' offset to produce 0-9 characters
                $chars[$i] = [char]([int][char]'0' + $script:Rand.Next(0,10))
            }
        }
        -join $chars
    }

    function New-RandomEmailLocalPart {
        param(
            [string]$First,
            [string]$Last
        )
        $n = $script:Rand.Next(10,99)
        if ($First -and $Last) {
            $lp = ("{0}.{1}{2}" -f ($First -replace "[^a-zA-Z]",""), ($Last -replace "[^a-zA-Z]",""), $n)
        } elseif ($First) {
            $lp = ("{0}{1}" -f ($First -replace "[^a-zA-Z]",""), $n)
        } elseif ($Last) {
            $lp = ("{0}{1}" -f ($Last -replace "[^a-zA-Z]",""), $n)
        } else {
            $alphabet = 'abcdefghijklmnopqrstuvwxyz'
            $lp = -join (1..8 | ForEach-Object { $alphabet[$script:Rand.Next(0,$alphabet.Length)] })
        }
        return ($lp.ToLower()).Trim('.')
    }

    function ConvertTo-RandomizedEmail {
        param(
            [Parameter(Mandatory=$true)]
            [string]$Email,
            [string]$First,
            [string]$Last
        )
        $trimmed = $Email.Trim()
        if (-not $trimmed) { return $Email }
        if ($trimmed -notmatch '@') { return $Email } # not a typical email, leave as-is
        $parts = $trimmed.Split('@',2)
        $domain = $parts[1]
        $local = New-RandomEmailLocalPart -First $First -Last $Last
        "$local@$domain"
    }

    function ConvertTo-RandomAlphaNumLike {
        param(
            [Parameter(Mandatory=$true)]
            [string]$Value,
            [string]$LetterSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        )
        if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }
        $letters = $LetterSet.ToCharArray()
        $chars = $Value.ToCharArray()
        for ($i=0; $i -lt $chars.Length; $i++) {
            $c = $chars[$i]
            if ([char]::IsDigit($c)) {
                $chars[$i] = [char]([int][char]'0' + $script:Rand.Next(0,10))
            } elseif ([char]::IsLetter($c)) {
                $rand = $letters[$script:Rand.Next(0,$letters.Length)]
                if ([char]::IsUpper($c)) { $chars[$i] = [char]::ToUpper($rand) } else { $chars[$i] = [char]::ToLower($rand) }
            }
        }
        -join $chars
    }

    # Generate a randomized-but-plausible street address, preserving any leading number/unit pattern
    $StreetBases = @(
        'Maple','Oak','Cedar','Pine','Elm','Ash','Birch','Willow','Spruce','Poplar',
        'Chestnut','Hawthorn','Meadow','Prairie','River','Lake','Sunset','Raven','Fox','Deer',
        'Eagle','Hillcrest','Highland','Kenwood','Southbridge','Barrmill','Stanley','Dodds','Edgewood',
        'Arbor','Poplarwood','Kingfisher','Hindle','Almington','Oblik','Mulvey','Arbourwood','Edge Park'
    )
    $StreetSuffixes = @('Street','St','Avenue','Ave','Road','Rd','Drive','Dr','Crescent','Court','Ct','Bay','Gate','Boulevard','Blvd','Lane','Ln','Terrace','Way','Place','Square','Trail')

    # City and Province pools (Canadian context)
    $CityPool = @(
        'Winnipeg','Toronto','Vancouver','Calgary','Edmonton','Ottawa','Montreal','Halifax','Regina','Saskatoon',
    'London','Kitchener','Waterloo','Hamilton','Victoria','Kelowna','Quebec City','Moncton','St. John''s','Charlottetown'
    )
    $ProvincePool = @('MB','ON','BC','AB','SK','QC','NS','NB','NL','PE')

    function New-RandomStreetFromOriginal {
        param(
            [Parameter(Mandatory=$true)]
            [string]$Original
        )
        if ([string]::IsNullOrWhiteSpace($Original)) { return $Original }

        # Find index of first alphabetic character
        $firstLetterIdx = -1
        for ($i=0; $i -lt $Original.Length; $i++) {
            if ([char]::IsLetter($Original[$i])) { $firstLetterIdx = $i; break }
        }

        if ($firstLetterIdx -gt 0) {
            # Preserve and randomize the leading numeric/unit-like prefix
            $prefix = $Original.Substring(0, $firstLetterIdx)
            $prefixRand = ConvertTo-RandomAlphaNumLike -Value $prefix -LetterSet 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            if ($prefixRand -and $prefixRand[-1] -ne ' ') { $prefixRand += ' ' }
        } elseif ($firstLetterIdx -eq 0) {
            # Starts with a letter: synthesize a plausible house number
            $prefixRand = ("{0} " -f $script:Rand.Next(1, 9999))
        } else {
            # No letters at all (rare) — randomize the entire string as prefix
            $prefixRand = ConvertTo-RandomAlphaNumLike -Value $Original -LetterSet 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            if ($prefixRand -and $prefixRand[-1] -ne ' ') { $prefixRand += ' ' }
        }

        $base = Get-RandItem -Array $StreetBases
        $suf  = Get-RandItem -Array $StreetSuffixes
        ($prefixRand + ("{0} {1}" -f $base, $suf)).Trim()
    }

    # Build student number -> student name map if provided or discoverable
    $script:StudentMap = @{}
    $studentsPathToUse = $null
    if ($PSBoundParameters.ContainsKey('StudentCsvPath') -and $StudentCsvPath) {
        $studentsPathToUse = $StudentCsvPath
    } else {
        # Try default: repoRoot/data/examples/students_example.csv, based on this script's folder
        $repoRoot = Split-Path -Parent $PSCommandPath | Split-Path -Parent
        $candidate = Join-Path $repoRoot 'data/examples/students_example.csv'
        if (Test-Path -LiteralPath $candidate) { $studentsPathToUse = $candidate }
    }
    if ($studentsPathToUse -and (Test-Path -LiteralPath $studentsPathToUse)) {
        try {
            $students = Import-Csv -LiteralPath $studentsPathToUse
            foreach ($s in $students) {
                $num = ($s.Student_Number).ToString().Trim()
                if (-not [string]::IsNullOrWhiteSpace($num)) {
                    $first = ($s.First_Name).ToString().Trim()
                    $last  = ($s.Last_Name).ToString().Trim()
                    $parts = @()
                    if ($first) { $parts += $first }
                    if ($last)  { $parts += $last }
                    $name = ($parts -join ' ').Trim()
                    if (-not [string]::IsNullOrWhiteSpace($name)) {
                        $script:StudentMap[$num] = $name
                    }
                }
            }
            Write-Verbose ("Loaded student map: {0} entries from {1}" -f $script:StudentMap.Count, $studentsPathToUse)
        } catch {
            Write-Warning "Failed to load students CSV from '$studentsPathToUse': $($_.Exception.Message)"
        }
    } else {
        Write-Verbose "No students CSV found/provided; skipping '* NOT MAPPED *' population."
    }
}

process {
    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input file not found: $InputPath"
    }

    $rows = Import-Csv -LiteralPath $InputPath

    if (-not $rows) {
        Write-Warning "No rows found in input CSV. Writing empty output."
        $rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded
        return
    }

    # Detect available columns (supporting different header styles)
    $propNames = $rows[0].PSObject.Properties.Name
    function Get-FirstPresentName {
        param([string[]]$Candidates)
        foreach ($c in $Candidates) { if ($propNames -contains $c) { return $c } }
        return $null
    }

    $firstNameCol  = Get-FirstPresentName -Candidates @('First Name','First_Name')
    $middleNameCol = Get-FirstPresentName -Candidates @('Middle Name','Middle_Name')
    $lastNameCol   = Get-FirstPresentName -Candidates @('Last Name','Last_Name')

    # Validate that at least first/last are present; otherwise skip name anonymization
    $canAnonymizeNames = ($null -ne $firstNameCol -and $null -ne $lastNameCol)
    if (-not $canAnonymizeNames) {
        Write-Verbose "Name columns not fully present; skipping name anonymization."
    }

    # Phones
    $phoneCols = @()
    foreach ($cand in @('phoneNumberAsEntered','Home_Phone')) { if ($propNames -contains $cand) { $phoneCols += $cand } }
    # Add any other columns that contain 'Phone' exactly as in students (already covered) – avoid IDs

    # Emails: any header that includes 'email' but not 'id' (case-insensitive)
    $emailCols = @()
    foreach ($p in $propNames) { if ($p -match '(?i)email' -and $p -notmatch '(?i)id$') { $emailCols += $p } }

    # Address columns: primary + mailing variants
    $streetCols = @(); foreach ($c in @('Street','Mailing_Street')) { if ($propNames -contains $c) { $streetCols += $c } }
    $cityCols   = @(); foreach ($c in @('City','Mailing_City'))   { if ($propNames -contains $c) { $cityCols   += $c } }
    $stateCols  = @(); foreach ($c in @('State','Mailing_State')) { if ($propNames -contains $c) { $stateCols  += $c } }
    $postalCols = @(); foreach ($c in @('Postal Code','Zip','Mailing_Zip')) { if ($propNames -contains $c) { $postalCols += $c } }

    $changed = 0
    $changedPhone = 0
    $changedEmail = 0
    $changedStudentMap = 0
    $changedStreet = 0
    $changedPostal = 0
    $changedCity = 0
    $changedProvince = 0
    foreach ($row in $rows) {
        # Names
        if ($canAnonymizeNames) {
            $origFirst = $row.$firstNameCol
            $origMiddle = $null; if ($middleNameCol) { $origMiddle = $row.$middleNameCol }
            $origLast = $row.$lastNameCol

            if ($null -ne $origFirst -and "$origFirst".Trim().Length -gt 0) { $row.$firstNameCol = Get-RandItem -Array $FirstNames }
            if ($middleNameCol -and $null -ne $origMiddle -and "$origMiddle".Trim().Length -gt 0) { $row.$middleNameCol = Get-RandItem -Array $MiddleNames }
            if ($null -ne $origLast -and "$origLast".Trim().Length -gt 0) { $row.$lastNameCol = Get-RandItem -Array $LastNames }

            if ($row.$firstNameCol -ne $origFirst -or ($middleNameCol -and $row.$middleNameCol -ne $origMiddle) -or $row.$lastNameCol -ne $origLast) { $changed++ }
        }

        # Phones
        foreach ($pc in $phoneCols) {
            $origPhone = $row.$pc
            if ($null -ne $origPhone -and "$origPhone".Trim().Length -gt 0) {
                $newPhone = ConvertTo-RandomPhoneLike -Value "$origPhone"
                if ($newPhone -ne $origPhone) { $row.$pc = $newPhone; $changedPhone++ }
            }
        }

        # Emails
        foreach ($ec in $emailCols) {
            $origEmail = $row.$ec
            if ($null -ne $origEmail -and "$origEmail".Trim().Length -gt 0 -and ("$origEmail" -match '@')) {
                $firstVal = if ($canAnonymizeNames) { $row.$firstNameCol } else { '' }
                $lastVal  = if ($canAnonymizeNames)  { $row.$lastNameCol }  else { '' }
                $newEmail = ConvertTo-RandomizedEmail -Email "$origEmail" -First $firstVal -Last $lastVal
                if ($newEmail -ne $origEmail) { $row.$ec = $newEmail; $changedEmail++ }
            }
        }

        # Streets
        foreach ($sc in $streetCols) {
            $origStreet = $row.$sc
            if ($null -ne $origStreet -and "$origStreet".Trim().Length -gt 0) {
                $newStreet = New-RandomStreetFromOriginal -Original "$origStreet"
                if ($newStreet -ne $origStreet) { $row.$sc = $newStreet; $changedStreet++ }
            }
        }

        # Postal/Zip
        foreach ($pcz in $postalCols) {
            $origPostal = $row.$pcz
            if ($null -ne $origPostal -and "$origPostal".Trim().Length -gt 0) {
                $newPostal = ConvertTo-RandomAlphaNumLike -Value "$origPostal" -LetterSet 'ABCEGHJKLMNPRSTVWXYZ'
                if ($newPostal -ne $origPostal) { $row.$pcz = $newPostal; $changedPostal++ }
            }
        }

        # Cities
        foreach ($cc in $cityCols) {
            $origCity = $row.$cc
            if ($null -ne $origCity -and "$origCity".Trim().Length -gt 0) {
                $newCity = Get-RandItem -Array $CityPool
                if ($newCity -ne $origCity) { $row.$cc = $newCity; $changedCity++ }
            }
        }

        # Provinces/States
        foreach ($stc in $stateCols) {
            $origProvince = $row.$stc
            if ($null -ne $origProvince -and "$origProvince".Trim().Length -gt 0) {
                $newProv = Get-RandItem -Array $ProvincePool
                if ($newProv -ne $origProvince) { $row.$stc = $newProv; $changedProvince++ }
            }
        }

        # Populate student relationship label in '* NOT MAPPED *' using studentNumber when available (parents CSV only)
        $origStudentText = $row.'* NOT MAPPED *'
        $studNum = $row.studentNumber
        if ($script:StudentMap.Count -gt 0 -and $null -ne $studNum -and "$studNum".Trim().Length -gt 0) {
            $key = ("$studNum").Trim()
            if ($script:StudentMap.ContainsKey($key)) {
                $newText = $script:StudentMap[$key]
                if ($newText -and $newText -ne $origStudentText) { $changedStudentMap++ }
                $row.'* NOT MAPPED *' = $newText
            }
        }
    }

    $dir = Split-Path -Parent -Path $OutputPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        Write-Verbose "Creating output directory: $dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded

    Write-Verbose ("Anonymized name rows: {0}" -f $changed)
    Write-Verbose ("Randomized phone numbers: {0}" -f $changedPhone)
    Write-Verbose ("Randomized email addresses: {0}" -f $changedEmail)
    Write-Verbose ("Randomized street addresses: {0}" -f $changedStreet)
    Write-Verbose ("Randomized postal codes: {0}" -f $changedPostal)
    Write-Verbose ("Randomized cities: {0}" -f $changedCity)
    Write-Verbose ("Randomized provinces/states: {0}" -f $changedProvince)
    if ($changedStudentMap -gt 0) { Write-Verbose ("Updated '* NOT MAPPED *' (student labels): {0}" -f $changedStudentMap) }
    Write-Verbose "Wrote output to: $OutputPath"
}
