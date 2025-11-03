#Requires -Version 7.0

<#
.SYNOPSIS
    Imports and normalizes parent/contact data from a CSV file.

.DESCRIPTION
    Parses a Final Site Enrollment parents CSV export and converts it to normalized
    PowerSchool entities (Contacts, PhoneNumbers, EmailAddresses, Addresses, and Relationships).
    
    This CSV has a complex multi-row format:
    - First row for a contact contains full contact information (name, email, address, first phone)
    - Additional rows with same ContactIdentifier but only phone data are extra phone numbers
    - Rows with a studentNumber value are relationship records linking contact to student
    
    This function uses a template-based approach with a custom parser function specified in the
    template configuration to handle the complex multi-row format.

.PARAMETER Path
    Path to the parents CSV file to import.

.PARAMETER TemplateName
    Template name to use for parsing. Defaults to 'fs_powerschool_nonapi_report_parents'.

.OUTPUTS
    PSNormalizedData object containing Contacts, PhoneNumbers, EmailAddresses, Addresses, and Relationships.

.EXAMPLE
    $data = Import-FSParentsCsv -Path './data/parents.csv'
    
    Imports parent/contact data from the specified CSV file.

.EXAMPLE
    $data = Import-FSParentsCsv -Path './data/parents.csv'
    Write-Host "Imported $($data.Contacts.Count) contacts"
    Write-Host "Imported $($data.Relationships.Count) student-contact relationships"

.NOTES
    This function handles the complex multi-row format using a custom parser defined in the template.
    It is designed to work cross-platform on Linux and Windows.
#>
function Import-FSParentsCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$TemplateName = 'fs_powerschool_nonapi_report_parents'
    )

    begin {
        Write-Verbose "Starting parent CSV import from: $Path"
        
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
                
                # Invoke the custom parser function
                $normalizedData = & $templateConfig.CustomParser -CsvData $csvData
            }
            else {
                # Use standard template-based parsing (for future simple formats)
                Write-Verbose "Using standard template-based parsing"
                $normalizedData = [PSNormalizedData]::new()
                
                foreach ($row in $csvData) {
                    $entity = ConvertFrom-CsvRow -CsvRow $row -TemplateConfig $templateConfig
                    # Add to appropriate collection based on EntityType
                    # This would need to be expanded based on entity type
                    $normalizedData.Contacts.Add($entity)
                }
            }

            return $normalizedData
        }
        catch {
            Write-Error "Failed to import parents CSV: $_"
            throw
        }
    }

    end {
        Write-Verbose "Parent CSV import completed"
    }
}
