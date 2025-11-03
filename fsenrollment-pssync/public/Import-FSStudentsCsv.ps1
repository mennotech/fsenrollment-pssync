#Requires -Version 7.0

<#
.SYNOPSIS
    Imports and normalizes student data from a CSV file using the fs_powerschool_nonapi_report_students template.

.DESCRIPTION
    Parses a Final Site Enrollment students CSV export and converts it to normalized
    PowerSchool student entities. The CSV is expected to have one row per student with
    standard student demographic and enrollment information.

.PARAMETER Path
    Path to the students CSV file to import.

.PARAMETER TemplateName
    Optional template name. Defaults to 'fs_powerschool_nonapi_report_students'.

.OUTPUTS
    PSNormalizedData object containing the imported students in the Students collection.

.EXAMPLE
    $data = Import-FSStudentsCsv -Path './data/students.csv'
    
    Imports students from the specified CSV file.

.EXAMPLE
    $data = Import-FSStudentsCsv -Path './data/students.csv'
    $data.Students | ForEach-Object { Write-Host "$($_.FirstName) $($_.LastName)" }
    
    Imports students and displays their names.

.NOTES
    This function is designed to work cross-platform on Linux and Windows.
#>
function Import-FSStudentsCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$TemplateName = 'fs_powerschool_nonapi_report_students'
    )

    begin {
        Write-Verbose "Starting student CSV import from: $Path"
        
        # Load the template configuration
        $templatePath = Join-Path $script:ModuleRoot "/../config/templates/$TemplateName.psd1"
        
        if (-not (Test-Path $templatePath)) {
            throw "Template configuration not found: $templatePath"
        }
        
        Write-Verbose "Loading template: $templatePath"
        $templateConfig = Import-PowerShellDataFile -Path $templatePath
    }

    process {
        try {
            # Import CSV file
            Write-Verbose "Importing CSV file..."
            $csvData = Import-Csv -Path $Path

            if ($null -eq $csvData -or $csvData.Count -eq 0) {
                Write-Warning "No data found in CSV file: $Path"
                return [PSNormalizedData]::new()
            }

            Write-Verbose "Found $($csvData.Count) rows in CSV"

            # Create normalized data container
            $normalizedData = [PSNormalizedData]::new()

            # Process each row
            foreach ($row in $csvData) {
                $student = ConvertFrom-CsvRow -CsvRow $row -TemplateConfig $templateConfig
                $normalizedData.Students.Add($student)
            }

            Write-Verbose "Successfully imported $($normalizedData.Students.Count) students"
            return $normalizedData
        }
        catch {
            Write-Error "Failed to import students CSV: $_"
            throw
        }
    }

    end {
        Write-Verbose "Student CSV import completed"
    }
}
