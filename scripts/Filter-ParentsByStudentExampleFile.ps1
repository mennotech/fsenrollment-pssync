<#
.SYNOPSIS
Filters a Final Site Enrollment parents CSV to only include:
- parent demographic rows and their additional contact records, and
- relationship rows that link parents to students present in a students CSV (via the studentNumber column).

.DESCRIPTION
This script reads a parents CSV (with grouped rows by New Contact Identifier) and a students CSV. It determines which
parents have relationship records referencing a studentNumber that exists in the students file. It then outputs:
- Rows where studentNumber is empty for those qualifying parents (main parent row + extra email/phone/address), and
- Relationship rows where studentNumber is present and found in the students CSV.

.PARAMETER ParentsCsvPath
Path to the parents CSV (e.g., data/examples/parents_example.csv).

.PARAMETER StudentsCsvPath
Path to the students CSV (e.g., data/examples/students_example.csv).

.PARAMETER OutputPath
Path to write the filtered CSV (e.g., data/examples/parents_filtered.csv).

.EXAMPLE
./scripts/Filter-ParentsByStudents.ps1 -Verbose

.EXAMPLE
./scripts/Filter-ParentsByStudents.ps1 -ParentsCsvPath ./data/incoming/parents.csv -StudentsCsvPath ./data/incoming/students.csv -OutputPath ./data/processed/parents_filtered.csv -Verbose

.NOTES
- Cross-platform PowerShell 7+
- Assumes parents CSV has columns similar to the provided example, including:
  "New Contact Identifier" and "studentNumber" columns. Matching is case-insensitive.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ParentsCsvPath = (Join-Path -Path $PSScriptRoot -ChildPath '../data/examples/parents_example.csv' | Resolve-Path -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } | Select-Object -First 1),

    [Parameter(Mandatory=$false)]
    [string]$StudentsCsvPath = (Join-Path -Path $PSScriptRoot -ChildPath '../data/examples/students_example.csv' | Resolve-Path -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } | Select-Object -First 1),

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath '../data/examples/parents_filtered.csv')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ExistingPath([string]$path, [string]$fallback) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $fallback }
    if (Test-Path -LiteralPath $path) { return (Resolve-Path -LiteralPath $path).Path }
    # Try relative to repo root (script may be called from other cwd)
    if ($fallback -and (Test-Path -LiteralPath $fallback)) { return (Resolve-Path -LiteralPath $fallback).Path }
    return $path
}

function SafeTrim {
    param([object]$Value)
    if ($null -eq $Value) { return $null }
    return ($Value.ToString()).Trim()
}

# Normalize input paths
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$defaultParents = Join-Path $repoRoot 'data/examples/parents_example.csv'
$defaultStudents = Join-Path $repoRoot 'data/examples/students_example.csv'
$ParentsCsvPath = Get-ExistingPath -path $ParentsCsvPath -fallback $defaultParents
$StudentsCsvPath = Get-ExistingPath -path $StudentsCsvPath -fallback $defaultStudents

Write-Verbose "Parents CSV: $ParentsCsvPath"
Write-Verbose "Students CSV: $StudentsCsvPath"
Write-Verbose "Output path: $OutputPath"

if (-not (Test-Path -LiteralPath $ParentsCsvPath)) {
    throw "Parents CSV not found: $ParentsCsvPath"
}
if (-not (Test-Path -LiteralPath $StudentsCsvPath)) {
    throw "Students CSV not found: $StudentsCsvPath"
}

# Load CSVs
$students = Import-Csv -LiteralPath $StudentsCsvPath
$parents = Import-Csv -LiteralPath $ParentsCsvPath

if (-not $students) { throw 'Students CSV appears empty.' }
if (-not $parents) { throw 'Parents CSV appears empty.' }

# Helper: find a column name by pattern (case-insensitive)
function Find-ColumnName {
    param(
        [Parameter(Mandatory)] [string[]] $Candidates,
        [Parameter(Mandatory)] [string[]] $Available
    )
    foreach ($cand in $Candidates) {
        $exact = $Available | Where-Object { $_ -ieq $cand } | Select-Object -First 1
        if ($exact) { return $exact }
    }
    # Fuzzy matches (regex-like semantics provided in candidates)
    foreach ($cand in $Candidates) {
        $match = $Available | Where-Object { $_ -imatch $cand } | Select-Object -First 1
        if ($match) { return $match }
    }
    return $null
}

# Determine critical column names
$studentCols = @($students[0].PSObject.Properties.Name)
$parentsCols = @($parents[0].PSObject.Properties.Name)

$studentNumberCol = Find-ColumnName -Candidates @(
    'studentNumber',            # camelCase
    'Student_Number',           # underscore-separated as seen in example
    '^student[_\s]*number$'    # regex allowing underscores or spaces
) -Available $studentCols
if (-not $studentNumberCol) {
    throw "Could not find 'studentNumber' column in students CSV. Available: $($studentCols -join ', ')"
}

$parentIdCol = Find-ColumnName -Candidates @('New Contact Identifier','^new\s*contact\s*identifier$') -Available $parentsCols
if (-not $parentIdCol) {
    throw "Could not find 'New Contact Identifier' column in parents CSV. Available: $($parentsCols -join ', ')"
}

$parentStudentNumberCol = Find-ColumnName -Candidates @('studentNumber','^student\s*number$') -Available $parentsCols
if (-not $parentStudentNumberCol) {
    throw "Could not find 'studentNumber' column in parents CSV. Available: $($parentsCols -join ', ')"
}

# Build sets for fast membership checks
$validStudentNumbers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in $students) {
    $n = SafeTrim $s.$studentNumberCol
    if ($n) { [void]$validStudentNumbers.Add($n) }
}
Write-Verbose "Loaded $($validStudentNumbers.Count) studentNumbers from students CSV."

$qualifyingParentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# First pass: mark parent IDs that have any relationship row matching a valid studentNumber
foreach ($row in $parents) {
    $parentId = SafeTrim $row.$parentIdCol
    if (-not $parentId) { continue }
    $relStudent = SafeTrim $row.$parentStudentNumberCol
    if ([string]::IsNullOrWhiteSpace($relStudent)) { continue }
    if ($validStudentNumbers.Contains($relStudent)) {
        [void]$qualifyingParentIds.Add($parentId)
    }
}
Write-Verbose "Found $($qualifyingParentIds.Count) qualifying parent identifiers with matching student relationships."

# If none found, still produce an empty CSV with original headers
$parentsHeaderOrder = $parentsCols

# Second pass: include parent/contact rows for qualifying parents, and include relationship rows matching valid students
$filtered = $parents.Where({
    $parentId = SafeTrim $_.$parentIdCol
    if (-not $parentId) { return $false }
    $relStudent = SafeTrim $_.$parentStudentNumberCol
    if ([string]::IsNullOrWhiteSpace($relStudent)) {
        # Parent demographic or additional contact row
        return $qualifyingParentIds.Contains($parentId)
    } else {
        # Relationship row: only include if relates to a valid student
        return $validStudentNumbers.Contains($relStudent)
    }
}, 'Default')

# Ensure output directory exists
$outDir = Split-Path -Path $OutputPath -Parent
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    $null = New-Item -ItemType Directory -Path $outDir -Force
}

# Export with original header order
$filtered | Select-Object -Property $parentsHeaderOrder | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded

Write-Verbose ("Wrote {0} rows to {1}" -f ($filtered | Measure-Object | Select-Object -ExpandProperty Count), $OutputPath)
