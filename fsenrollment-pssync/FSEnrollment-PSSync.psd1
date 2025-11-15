@{
    # Script module or binary module file associated with this manifest
    RootModule = 'FSEnrollment-PSSync.psm1'

    # Version number of this module
    ModuleVersion = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'd3a9f2b4-6f1a-4c3b-8d2e-1f0a9b2c3d4e'

    # Author of this module
    Author = 'Mennotech'

    # Company or vendor of this module
    CompanyName = 'Mennotech'

    # Copyright statement for this module
    Copyright = '(c) 2025 Mennotech. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerSchool synchronization module for integrating Final Site Enrollment data with PowerSchool SIS. Automates data transfers and maintains consistency between systems.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    # Use an empty array if there are no functions to export
    FunctionsToExport = @(
        'Import-FSCsv'
        'Connect-PowerSchool'
        'Get-PowerSchoolStudent'
        'Compare-PSStudent'
        'Get-RequiredPowerSchoolFields'
        'Invoke-PowerQuery'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    # Use an empty array if there are no cmdlets to export
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    # Use an empty array if there are no aliases to export
    AliasesToExport = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # List of all modules packaged with this module
    ModuleList = @()

    # List of all files packaged with this module
    FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module to help with module discovery
            Tags = @('PowerSchool', 'FinalSiteEnrollment', 'Sync', 'Integration', 'SIS')

            # A URL to the license for this module
            LicenseUri = 'https://github.com/mennotech/fsenrollment-pssync/blob/main/LICENSE'

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/mennotech/fsenrollment-pssync'

            # A URL to an icon representing this module
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release - Module structure created'

            # Prerelease string of this module
            Prerelease = 'alpha'

            # Flag to indicate whether the module requires explicit user acceptance for install/update
            RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module
    # DefaultCommandPrefix = ''
}
