#Requires -Version 7.0

<#
.SYNOPSIS
    FSEnrollment-PSSync module for integrating Final Site Enrollment data with PowerSchool.

.DESCRIPTION
    This module provides functions to synchronize data between Final Site Enrollment
    and PowerSchool SIS. It handles CSV file parsing, change detection, logging, and API
    integration with PowerSchool.

.NOTES
    Author: Mennotech
    Version: 0.1.0
    License: MIT
#>

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot/public/*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot/private/*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
        Write-Verbose "Imported function: $($import.BaseName)"
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export only the public functions
Export-ModuleMember -Function $Public.BaseName

# Module variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = (Test-ModuleManifest -Path "$PSScriptRoot/FSEnrollment-PSSync.psd1").Version
$script:ModuleName = 'FSEnrollment-PSSync'

Write-Verbose "FSEnrollment-PSSync module loaded successfully (Version: $script:ModuleVersion)"
