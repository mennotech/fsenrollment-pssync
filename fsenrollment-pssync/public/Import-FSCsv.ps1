#Requires -Version 7.0

<#
.SYNOPSIS
    Imports and normalizes CSV data using a specified template.

.DESCRIPTION
    Parses a Final Site Enrollment CSV export and converts it to normalized
    PowerSchool entities based on the template configuration. The template
    determines the parsing approach (standard column mappings or custom parser)
    and the types of entities to return.

.PARAMETER Path
    Path to the CSV file to import.

.PARAMETER TemplateName
    Template name to use for parsing. The template file should exist in
    config/templates/ directory (e.g., 'fs_powerschool_nonapi_report_students').

.OUTPUTS
    PSNormalizedData object containing normalized entities as specified by the template.

.EXAMPLE
    $data = Import-FSCsv -Path './data/students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    
    Imports students from the CSV file using the specified template.

.EXAMPLE
    $data = Import-FSCsv -Path './data/parents.csv' -TemplateName 'fs_powerschool_nonapi_report_parents'
    Write-Host "Imported $($data.Contacts.Count) contacts"
    Write-Host "Imported $($data.Relationships.Count) student-contact relationships"

.NOTES
    This function is designed to work cross-platform on Linux and Windows.
    The template determines whether to use standard column mappings or a custom parser.
#>
function Import-FSCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$TemplateName
    )

    begin {
        Write-Verbose "Starting CSV import from: $Path"
        Write-Verbose "Using template: $TemplateName"
        
        # Load the template configuration
        $configRoot = Join-Path $script:ModuleRoot '..'
        $templatePath = Join-Path $configRoot "config/templates/$TemplateName.psd1"
        
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

            # Check if template specifies a custom parser
            if ($templateConfig.CustomParser) {
                Write-Verbose "Using custom parser: $($templateConfig.CustomParser)"
                
                # Load the custom parser from templates folder
                $parserPath = Join-Path $configRoot "config/templates/$($templateConfig.CustomParser).ps1"
                
                if (-not (Test-Path $parserPath)) {
                    throw "Custom parser file not found: $parserPath"
                }
                
                Write-Verbose "Loading custom parser from: $parserPath"
                . $parserPath
                
                # Invoke the custom parser function with template configuration
                $normalizedData = & $templateConfig.CustomParser -CsvData $csvData -TemplateConfig $templateConfig
            }
            else {
                # Use standard template-based parsing with ConvertFrom-CsvRow
                Write-Verbose "Using standard template-based parsing"
                $normalizedData = [PSNormalizedData]::new()
                
                # Determine the target collection based on EntityType
                $entityType = $templateConfig.EntityType
                
                foreach ($row in $csvData) {
                    $entity = ConvertFrom-CsvRow -CsvRow $row -TemplateConfig $templateConfig
                    
                    # Add to the appropriate collection based on entity type
                    switch ($entityType) {
                        'PSStudent' { $normalizedData.Students.Add($entity) }
                        'PSContact' { $normalizedData.Contacts.Add($entity) }
                        'PSEmailAddress' { $normalizedData.EmailAddresses.Add($entity) }
                        'PSPhoneNumber' { $normalizedData.PhoneNumbers.Add($entity) }
                        'PSAddress' { $normalizedData.Addresses.Add($entity) }
                        'PSStudentContactRelationship' { $normalizedData.Relationships.Add($entity) }
                        default {
                            Write-Warning "Unknown entity type: $entityType. Entity not added to normalized data."
                        }
                    }
                }
            }

            # Log summary based on what was imported
            $summary = @()
            if ($normalizedData.Students.Count -gt 0) { $summary += "$($normalizedData.Students.Count) students" }
            if ($normalizedData.Contacts.Count -gt 0) { $summary += "$($normalizedData.Contacts.Count) contacts" }
            if ($normalizedData.EmailAddresses.Count -gt 0) { $summary += "$($normalizedData.EmailAddresses.Count) email addresses" }
            if ($normalizedData.PhoneNumbers.Count -gt 0) { $summary += "$($normalizedData.PhoneNumbers.Count) phone numbers" }
            if ($normalizedData.Addresses.Count -gt 0) { $summary += "$($normalizedData.Addresses.Count) addresses" }
            if ($normalizedData.Relationships.Count -gt 0) { $summary += "$($normalizedData.Relationships.Count) relationships" }
            
            if ($summary.Count -gt 0) {
                Write-Verbose "Successfully imported: $($summary -join ', ')"
            }
            
            return $normalizedData
        }
        catch {
            Write-Error "Failed to import CSV: $_"
            throw
        }
    }

    end {
        Write-Verbose "CSV import completed"
    }
}
