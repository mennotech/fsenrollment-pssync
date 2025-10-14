#Requires -Version 7.0

<#
.SYNOPSIS
    Gets a CSV normalization template.

.DESCRIPTION
    Retrieves a normalization template configuration that defines how to map
    CSV columns from Final Site Enrollment to PowerSchool API field names.
    Templates are stored as .psd1 files in the config/normalization-templates directory.

.PARAMETER TemplateName
    The name of the normalization template to retrieve.
    Default is 'fs_powerschool_nonapi_report'.

.PARAMETER TemplatesPath
    Optional path to the templates directory. If not specified, uses the
    default path relative to the module root.

.OUTPUTS
    System.Collections.Hashtable
    Returns a hashtable containing the template configuration.

.EXAMPLE
    $template = Get-CsvNormalizationTemplate
    Gets the default 'fs_powerschool_nonapi_report' template.

.EXAMPLE
    $template = Get-CsvNormalizationTemplate -TemplateName 'custom_format'
    Gets a custom normalization template.

.EXAMPLE
    $template = Get-CsvNormalizationTemplate -TemplateName 'fs_powerschool_nonapi_report' -Verbose
    Gets the template with verbose output showing the template being loaded.

.NOTES
    Templates define field mappings, data types, transformations, and validation rules
    for normalizing CSV data to PowerSchool API format.
#>
function Get-CsvNormalizationTemplate {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplateName = 'fs_powerschool_nonapi_report',

        [Parameter(Mandatory = $false)]
        [string]$TemplatesPath
    )

    begin {
        Write-Verbose "Getting CSV normalization template: $TemplateName"
    }

    process {
        if ([string]::IsNullOrWhiteSpace($TemplatesPath)) {
            $moduleRoot = Split-Path -Parent $PSScriptRoot
            $repoRoot = Split-Path -Parent $moduleRoot
            $TemplatesPath = Join-Path $repoRoot 'config/normalization-templates'
        }

        $templateFile = Join-Path $TemplatesPath "$TemplateName.psd1"

        if (-not (Test-Path -LiteralPath $templateFile)) {
            throw "Template file not found: $templateFile"
        }

        Write-Verbose "Loading template from: $templateFile"

        try {
            $template = Import-PowerShellDataFile -Path $templateFile -ErrorAction Stop
            
            if (-not $template) {
                throw "Template file is empty or invalid: $templateFile"
            }

            if (-not $template.ContainsKey('Name')) {
                Write-Warning "Template does not contain a Name property"
            }

            Write-Verbose "Template loaded successfully: $($template.Name) v$($template.Version)"
            return $template
        }
        catch {
            throw "Failed to load template from $templateFile : $_"
        }
    }
}
