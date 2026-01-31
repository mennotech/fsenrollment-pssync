#Requires -Version 7.0

<#
.SYNOPSIS
    Applies student changes to PowerSchool based on comparison results.

.DESCRIPTION
    Takes the output from Compare-PSStudent (either as an object or from a JSON file)
    and applies the changes to PowerSchool via API calls. Supports creating new students
    and updating existing students.
    
    Includes robust error handling, retry logic, and the ability to limit the number
    of changes for testing purposes.
    
    Note: This function only applies student demographic changes. Contact information
    changes should be applied using a separate function.

.PARAMETER Changes
    PSCustomObject containing the comparison results from Compare-PSStudent.
    Must have New, Updated, and TemplateMetadata properties.
    TemplateMetadata is required for field mapping and must be included in the Changes object.

.PARAMETER JsonPath
    Path to a JSON file containing the comparison results.
    Alternative to providing Changes parameter.
    The JSON file must include TemplateMetadata for field mapping.

.PARAMETER Limit
    Maximum number of changes to apply. Useful for testing with live data.
    Default is unlimited (applies all changes).

.PARAMETER WhatIf
    Performs a dry run without making actual changes to PowerSchool.
    Displays detailed preview of what would be changed, including:
    - API endpoints that would be called
    - Field-by-field changes with old and new values
    - PowerSchool API field mappings
    - Complete JSON payloads that would be sent
    Use with -Verbose for full details. No PowerSchool connection required for preview.

.PARAMETER MaxRetries
    Maximum number of retry attempts for failed API calls. Default is 3.

.PARAMETER RetryDelaySeconds
    Initial retry delay in seconds. Default is 5.

.OUTPUTS
    PSCustomObject with properties:
    - NewStudentsApplied: Number of new students successfully created
    - UpdatedStudentsApplied: Number of students successfully updated
    - FailedChanges: List of changes that failed to apply
    - Summary: Summary statistics

.EXAMPLE
    # Apply all changes from a comparison result
    $changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psData
    $result = Submit-PSStudentChange -Changes $changes
    Write-Host "Applied $($result.NewStudentsApplied) new and $($result.UpdatedStudentsApplied) updated students"

.EXAMPLE
    # Apply changes from a JSON file with a limit for testing
    $result = Submit-PSStudentChange -JsonPath './data/pending_changes.json' -Limit 5
    Write-Host "Test run: Applied $($result.Summary.TotalApplied) of 5 changes"

.EXAMPLE
    # Dry run to preview changes without applying them (use with -Verbose for full details)
    Submit-PSStudentChange -JsonPath './data/pending_changes.json' -WhatIf -Verbose
    
    # Output shows API endpoints, field changes, and complete JSON payloads
    # Summary shows 0 applied since no changes are made in WhatIf mode

.EXAMPLE
    # Apply changes with custom retry settings
    Submit-PSStudentChange -Changes $changes -MaxRetries 5 -RetryDelaySeconds 10

.EXAMPLE
    # Complete workflow from CSV import to applying changes
    $csvData = Import-FSCsv -Path './students.csv' -TemplateName 'fs_powerschool_nonapi_report_students'
    $psData = Get-PowerSchoolStudent -All
    $changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psData
    Submit-PSStudentChange -Changes $changes

.NOTES
    Requires an active PowerSchool connection (Connect-PowerSchool must be called first).
    Uses the PowerSchool API v1 endpoints for creating and updating students.
    Only applies changes to student demographic fields, not contact information.
    TemplateMetadata is required and must be included in the Changes object from Compare-PSStudent.
    All field mappings are driven by the template configuration - no hardcoded mappings exist.
#>
function Submit-PSStudentChange {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Object')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Object', ValueFromPipeline = $true)]
        [PSCustomObject]$Changes,

        [Parameter(Mandatory = $true, ParameterSetName = 'Json')]
        [ValidateScript({ Test-Path $_ })]
        [string]$JsonPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit = [int]::MaxValue,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )

    begin {
        Write-Verbose "Starting Submit-PSStudentChange"
        
        # Check if connected to PowerSchool (skip for WhatIf to allow preview without connection)
        if (-not $WhatIfPreference) {
            if (-not $script:PowerSchoolToken -or -not $script:PowerSchoolBaseUrl) {
                throw "Not connected to PowerSchool. Please run Connect-PowerSchool first."
            }
        }
        
        # Initialize result tracking
        $script:ApplyResults = [PSCustomObject]@{
            NewStudentsApplied = 0
            UpdatedStudentsApplied = 0
            FailedChanges = [System.Collections.Generic.List[PSCustomObject]]::new()
            ProcessedCount = 0
        }
    }

    process {
        try {
            # Load changes from JSON if path provided
            if ($PSCmdlet.ParameterSetName -eq 'Json') {
                Write-Verbose "Loading changes from JSON file: $JsonPath"
                $jsonContent = Get-Content -Path $JsonPath -Raw
                $Changes = $jsonContent | ConvertFrom-Json
            }

            # Validate input structure
            if (-not $Changes.PSObject.Properties['New'] -or -not $Changes.PSObject.Properties['Updated']) {
                throw "Invalid changes object. Must contain 'New' and 'Updated' properties."
            }
            
            # Extract and validate TemplateMetadata from Changes object
            if (-not $Changes.PSObject.Properties['TemplateMetadata'] -or -not $Changes.TemplateMetadata) {
                throw "TemplateMetadata not found in Changes object. Ensure you're passing output from Compare-PSStudent which includes template metadata."
            }
            
            # Convert TemplateMetadata from PSCustomObject to Hashtable if needed (happens when loading from JSON)
            if ($Changes.TemplateMetadata -is [PSCustomObject]) {
                $TemplateMetadata = @{}
                foreach ($property in $Changes.TemplateMetadata.PSObject.Properties) {
                    if ($property.Value -is [Array]) {
                        # Convert array items if they're PSCustomObjects
                        $TemplateMetadata[$property.Name] = @($property.Value | ForEach-Object {
                            if ($_ -is [PSCustomObject]) {
                                $ht = @{}
                                foreach ($prop in $_.PSObject.Properties) {
                                    $ht[$prop.Name] = $prop.Value
                                }
                                $ht
                            } else {
                                $_
                            }
                        })
                    } else {
                        $TemplateMetadata[$property.Name] = $property.Value
                    }
                }
            } else {
                $TemplateMetadata = $Changes.TemplateMetadata
            }
            Write-Verbose "Using TemplateMetadata from Changes object (Template: $($TemplateMetadata.TemplateName))"

            # Calculate total changes to apply
            $totalChanges = $Changes.New.Count + $Changes.Updated.Count
            $changesToApply = [Math]::Min($totalChanges, $Limit)
            
            Write-Verbose "Total changes available: $totalChanges (New: $($Changes.New.Count), Updated: $($Changes.Updated.Count))"
            Write-Verbose "Changes to apply (with limit): $changesToApply"

            if ($WhatIfPreference) {
                Write-Host "WhatIf: Would apply $changesToApply of $totalChanges changes" -ForegroundColor Yellow
            }

            $changeNumber = 0

            # Process new students
            foreach ($newStudent in $Changes.New) {
                if ($changeNumber -ge $Limit) {
                    Write-Verbose "Reached limit of $Limit changes, stopping"
                    break
                }
                
                $changeNumber++
                Write-Progress -Activity "Applying Student Changes" `
                    -Status "Processing new student $changeNumber of $changesToApply" `
                    -PercentComplete (($changeNumber / $changesToApply) * 100)

                try {
                    $student = $newStudent.Student
                    $matchKey = $newStudent.MatchKey
                    
                    # Build student payload for API (always build for detailed display)
                    $payload = Build-StudentPayload -Student $student -TemplateMetadata $TemplateMetadata
                    
                    if ($WhatIfPreference) {
                        Write-Host "`n=== WHATIF: New Student Creation ===" -ForegroundColor Cyan
                        Write-Host "Student: $matchKey ($($student.FirstName) $($student.LastName))" -ForegroundColor Yellow
                        Write-Verbose "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/v1/student" -ForegroundColor Gray
                        
                        # Show field details for new student - iterate dynamically
                        Write-Host "Student Fields to Create:" -ForegroundColor Gray
                        $studentData = $payload.students.student
                        
                        # Display standard fields
                        foreach ($key in ($studentData.Keys | Where-Object { $_ -notin @('client_uid', 'action', 'name', 'id') } | Sort-Object)) {
                            $value = $studentData[$key]
                            if ($null -ne $value -and $value -ne '') {
                                # Format the field name for display
                                $displayName = ($key -replace '_', ' ').ToUpper()
                                $displayName = (Get-Culture).TextInfo.ToTitleCase($displayName.ToLower())
                                Write-Host "  ${displayName}: $value" -ForegroundColor White
                            }
                        }
                        
                        # Display name fields if present
                        if ($studentData.name) {
                            foreach ($nameKey in ($studentData.name.Keys | Sort-Object)) {
                                $value = $studentData.name[$nameKey]
                                if ($null -ne $value -and $value -ne '') {
                                    $displayName = ($nameKey -replace '_', ' ').ToUpper()
                                    $displayName = (Get-Culture).TextInfo.ToTitleCase($displayName.ToLower())
                                    Write-Host "  ${displayName}: $value" -ForegroundColor White
                                }
                            }
                        }
                        
                        # Only show full payload with -Verbose
                        Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10)"
                    }
                    
                    if ($PSCmdlet.ShouldProcess("New Student: $matchKey ($($student.FirstName) $($student.LastName))", "Create in PowerSchool")) {
                        if (-not $WhatIfPreference) {
                            Write-Verbose "Creating new student: $matchKey"
                            Write-Verbose "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/v1/student"
                            Write-Verbose "Student fields being created:"
                            $studentData = $payload.students.student
                            
                            # Display standard fields
                            foreach ($key in ($studentData.Keys | Where-Object { $_ -notin @('client_uid', 'action', 'name', 'id') } | Sort-Object)) {
                                $value = $studentData[$key]
                                if ($null -ne $value -and $value -ne '') {
                                    Write-Verbose "  ${key}: $value"
                                }
                            }
                            
                            # Display name fields if present
                            if ($studentData.name) {
                                foreach ($nameKey in ($studentData.name.Keys | Sort-Object)) {
                                    $value = $studentData.name[$nameKey]
                                    if ($null -ne $value -and $value -ne '') {
                                        Write-Verbose "  name.${nameKey}: $value"
                                    }
                                }
                            }
                            
                            Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10 -Compress)"
                            
                            # Make API call to create student
                            $result = Invoke-CreateStudent -Payload $payload -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                            
                            if ($result.Success) {
                                $script:ApplyResults.NewStudentsApplied++
                                Write-Host "✓ Created new student: $matchKey ($($student.FirstName) $($student.LastName))" -ForegroundColor Green
                                Write-Verbose "Successfully created student with API response: $($result.Response | ConvertTo-Json -Depth 10 -Compress)"
                            } else {
                                throw $result.Error
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to create new student $matchKey : $_"
                    $script:ApplyResults.FailedChanges.Add([PSCustomObject]@{
                        Type = 'New'
                        MatchKey = $matchKey
                        Student = $newStudent.Student
                        Error = $_.Exception.Message
                    })
                }
                
                $script:ApplyResults.ProcessedCount++
            }

            # Process updated students
            foreach ($updatedStudent in $Changes.Updated) {
                if ($changeNumber -ge $Limit) {
                    Write-Verbose "Reached limit of $Limit changes, stopping"
                    break
                }
                
                $changeNumber++
                Write-Progress -Activity "Applying Student Changes" `
                    -Status "Processing updated student $changeNumber of $changesToApply" `
                    -PercentComplete (($changeNumber / $changesToApply) * 100)

                try {
                    $matchKey = $updatedStudent.MatchKey
                    $changes = $updatedStudent.Changes
                    # Handle both single change object and array of changes
                    if ($changes -and -not ($changes -is [array])) {
                        $changes = @($changes)
                    }
                    $psStudent = $updatedStudent.PowerSchoolStudent
                    
                    # Get student DCID for update
                    if (-not $psStudent -and $updatedStudent.StudentDCID) {
                        # If PowerSchoolStudent not provided but StudentDCID is, fetch the student
                        Write-Verbose "Fetching PowerSchool student with DCID: $($updatedStudent.StudentDCID)"
                        $psStudent = Get-PowerSchoolStudent -DCID $updatedStudent.StudentDCID -Expansions @('demographics')
                    }
                    
                    $dcid = $psStudent.id
                    if (-not $dcid) {
                        throw "PowerSchool student DCID not found for $matchKey"
                    }
                    
                    # Build update payload (always build for detailed display)
                    $payload = Build-UpdatePayload -Changes $changes -StudentDCID $dcid -PowerSchoolStudent $psStudent -TemplateMetadata $TemplateMetadata
                    $updateMessage = "Student: $matchKey (DCID: $dcid) Name: $($psStudent.name.first_name) $($psStudent.name.middle_name) $($psStudent.name.last_name) - $($changes.Count) changes Fields: $($changes.Field -join ', ')"
                    if ($WhatIfPreference) {
                        Write-Verbose "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/v1/student"
                        Write-Verbose "Field Changes ($($changes.Count) total):"
                        foreach ($change in $changes) {
                            Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                            # Use the PowerSchoolAPIField from the change item if available, otherwise look it up
                            $mappingDesc = if ($change.PowerSchoolAPIField) {
                                $change.PowerSchoolAPIField
                            } else {
                                Get-PowerSchoolFieldMapping -EntityProperty $change.Field -TemplateMetadata $TemplateMetadata
                            }
                            if ($mappingDesc) {
                                Write-Verbose "    (API Field: $mappingDesc)"
                            }
                        }
                        
                        # Only show full payload with -Verbose
                        Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10)"
                    }
                    
                    if ($PSCmdlet.ShouldProcess($updateMessage, "Update in PowerSchool")) {
                        if (-not $WhatIfPreference) {
                            Write-Verbose "Updating student: $matchKey (DCID: $dcid) with $($changes.Count) changes"
                            Write-Verbose "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/v1/student"
                            Write-Verbose "Changes being applied:"
                            foreach ($change in $changes) {
                                Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                                # Use the PowerSchoolAPIField from the change item if available, otherwise look it up
                                $mappingDesc = if ($change.PowerSchoolAPIField) {
                                    $change.PowerSchoolAPIField
                                } else {
                                    Get-PowerSchoolFieldMapping -EntityProperty $change.Field -TemplateMetadata $TemplateMetadata
                                }
                                if ($mappingDesc) {
                                    Write-Verbose "    API Field: $mappingDesc"
                                }
                            }
                            Write-Verbose "API Payload: $($payload | ConvertTo-Json -Depth 10 -Compress)"
                            
                            # Make API call to update student
                            $result = Invoke-UpdateStudent -DCID $dcid -Payload $payload -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                            
                            if ($result.Success) {
                                $script:ApplyResults.UpdatedStudentsApplied++
                                Write-Host "✓ $updateMessage" -ForegroundColor Cyan
                                foreach ($change in $changes) {
                                    Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                                }
                                Write-Verbose "Successfully updated student with API response: $($result.Response | ConvertTo-Json -Depth 10 -Compress)"
                            } else {
                                throw $result.Error
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to update student $matchKey : $_"
                    $script:ApplyResults.FailedChanges.Add([PSCustomObject]@{
                        Type = 'Update'
                        MatchKey = $matchKey
                        Changes = $updatedStudent.Changes
                        Error = $_.Exception.Message
                    })
                }
                
                $script:ApplyResults.ProcessedCount++
            }

            Write-Progress -Activity "Applying Student Changes" -Completed
        }
        catch {
            Write-Error "Failed to apply student changes: $_"
            throw
        }
    }

    end {
        # Create summary
        $summary = [PSCustomObject]@{
            TotalProcessed = $script:ApplyResults.ProcessedCount
            TotalApplied = $script:ApplyResults.NewStudentsApplied + $script:ApplyResults.UpdatedStudentsApplied
            TotalFailed = $script:ApplyResults.FailedChanges.Count
            LimitApplied = $Limit -lt [int]::MaxValue
        }

        # Create final result
        $result = [PSCustomObject]@{
            NewStudentsApplied = $script:ApplyResults.NewStudentsApplied
            UpdatedStudentsApplied = $script:ApplyResults.UpdatedStudentsApplied
            FailedChanges = $script:ApplyResults.FailedChanges
            Summary = $summary
        }

        # Display summary
        Write-Host "`n=== Apply Changes Summary ===" -ForegroundColor Yellow
        Write-Host "New Students Created: $($result.NewStudentsApplied)" -ForegroundColor Green
        Write-Host "Students Updated: $($result.UpdatedStudentsApplied)" -ForegroundColor Cyan
        Write-Host "Failed Changes: $($result.Summary.TotalFailed)" -ForegroundColor $(if ($result.Summary.TotalFailed -gt 0) { 'Red' } else { 'Gray' })
        Write-Host "Total Applied: $($result.Summary.TotalApplied) of $($result.Summary.TotalProcessed) processed"
        
        if ($result.FailedChanges.Count -gt 0) {
            Write-Warning "`nSome changes failed. Check FailedChanges property for details."
        }

        Write-Verbose "Submit-PSStudentChange completed"
        
        return $result
    }
}

# Private helper function to build student payload for creation
function Build-StudentPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSStudent]$Student,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateMetadata
    )

    # Build basic student object
    $payload = @{
        students = @{
            student = @{
                client_uid = $Student.StudentNumber  # Use StudentNumber as client_uid
                action = "INSERT"
            }
        }
    }

    $studentData = $payload.students.student

    # Iterate through all properties of the Student object and map them dynamically
    $studentProperties = $Student.PSObject.Properties | Where-Object { $null -ne $_.Value -and $_.Value -ne '' }
    
    foreach ($property in $studentProperties) {
        $propertyName = $property.Name
        $propertyValue = $property.Value
        
        # Skip StudentNumber as it's already set as client_uid
        if ($propertyName -eq 'StudentNumber') {
            # Also set it as local_id
            $psFieldPath = Get-PowerSchoolFieldMapping -EntityProperty $propertyName -TemplateMetadata $TemplateMetadata
            if ($psFieldPath) {
                Set-PowerSchoolFieldValue -StudentData $studentData -FieldPath $psFieldPath -Value $propertyValue
            }
            continue
        }
        
        # Get the PowerSchool API field mapping for this property
        $psFieldPath = Get-PowerSchoolFieldMapping -EntityProperty $propertyName -TemplateMetadata $TemplateMetadata
        
        if ($psFieldPath) {
            # Apply the value using the field path
            Set-PowerSchoolFieldValue -StudentData $studentData -FieldPath $psFieldPath -Value $propertyValue
        } else {
            Write-Verbose "No PowerSchool API field mapping found for property: $propertyName (skipping)"
        }
    }

    return $payload
}

# Private helper function to merge expansion field changes with existing PowerSchool data
function Merge-ExpansionFieldChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$StudentData,
        
        [Parameter(Mandatory = $true)]
        [array]$ExpansionChanges,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PowerSchoolStudent,
        
        [Parameter(Mandatory = $true)]
        [string]$ExpansionName
    )
    
    # Pattern to match expansion fields: @expansionName.subtype.field or @expansionName.field
    # Examples: @addresses.physical.street, @demographics.birth_date
    $pattern = "^@$ExpansionName\.(.+)$"
    
    # Determine if this expansion type requires merging all existing fields
    # Addresses require all fields (street, city, state, postal_code) to be submitted together
    # Other expansions like demographics can be updated with just the changed fields
    $requiresFullMerge = $ExpansionName -in @('addresses')
    
    # Group changes by subtype (e.g., physical/mailing for addresses, or direct field for demographics)
    $groupedChanges = @{}
    
    foreach ($change in $ExpansionChanges) {
        if ($change.PowerSchoolAPIField -match $pattern) {
            $fieldPath = $matches[1]  # e.g., "physical.street" or "birth_date"
            
            # Check if there's a subtype (nested level)
            if ($fieldPath -match '^([^.]+)\.(.+)$') {
                # Has subtype: e.g., physical.street
                $subType = $matches[1]
                $fieldName = $matches[2]
                
                if (-not $groupedChanges.ContainsKey($subType)) {
                    $groupedChanges[$subType] = @()
                }
                $groupedChanges[$subType] += @{
                    Change = $change
                    FieldName = $fieldName
                }
            } else {
                # Direct field: e.g., birth_date
                if (-not $groupedChanges.ContainsKey('_direct')) {
                    $groupedChanges['_direct'] = @()
                }
                $groupedChanges['_direct'] += @{
                    Change = $change
                    FieldName = $fieldPath
                }
            }
        }
    }
    
    # Process each group
    foreach ($groupKey in $groupedChanges.Keys) {
        if ($groupKey -eq '_direct') {
            # Direct expansion fields (no subtype)
            Write-Verbose "Processing $ExpansionName changes"
            
            # Create the expansion structure if not exists
            if (-not $StudentData[$ExpansionName]) {
                $StudentData[$ExpansionName] = @{}
            }
            
            if ($requiresFullMerge) {
                # Merge with existing data - copy all existing fields first
                $existingData = if ($PowerSchoolStudent.$ExpansionName) {
                    $PowerSchoolStudent.$ExpansionName
                } else {
                    @{}
                }
                
                foreach ($prop in $existingData.PSObject.Properties) {
                    $StudentData[$ExpansionName][$prop.Name] = $prop.Value
                }
            }
            
            # Apply the changed fields on top
            foreach ($item in $groupedChanges[$groupKey]) {
                $StudentData[$ExpansionName][$item.FieldName] = $item.Change.NewValue
                Write-Verbose "  Updated $ExpansionName.$($item.FieldName) = $($item.Change.NewValue)"
            }
        } else {
            # Subtyped expansion fields (e.g., addresses.physical)
            Write-Verbose "Processing $ExpansionName.$groupKey changes"
            
            # Create the nested structure if not exists
            if (-not $StudentData[$ExpansionName]) {
                $StudentData[$ExpansionName] = @{}
            }
            if (-not $StudentData[$ExpansionName][$groupKey]) {
                $StudentData[$ExpansionName][$groupKey] = @{}
            }
            
            if ($requiresFullMerge) {
                # Merge with existing data - copy all existing fields first
                $existingData = if ($PowerSchoolStudent.$ExpansionName -and $PowerSchoolStudent.$ExpansionName.$groupKey) {
                    $PowerSchoolStudent.$ExpansionName.$groupKey
                } else {
                    @{}
                }
                
                foreach ($prop in $existingData.PSObject.Properties) {
                    $StudentData[$ExpansionName][$groupKey][$prop.Name] = $prop.Value
                }
            }
            
            # Apply the changed fields on top
            foreach ($item in $groupedChanges[$groupKey]) {
                $StudentData[$ExpansionName][$groupKey][$item.FieldName] = $item.Change.NewValue
                Write-Verbose "  Updated $ExpansionName.$groupKey.$($item.FieldName) = $($item.Change.NewValue)"
            }
        }
    }
}

# Private helper function to merge extension field changes into student data
function Merge-ExtensionFieldChanges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$StudentData,
        
        [Parameter(Mandatory = $true)]
        [array]$ExtensionChanges,
        
        [Parameter(Mandatory = $true)]
        [string]$TableName
    )
    
    # Pattern to match extension fields: extension.table_name.field_name
    $pattern = "^extension\.$TableName\.(.+)$"
    
    Write-Verbose "Processing extension table '$TableName' changes"
    
    # Create the _extension_data structure if not exists
    if (-not $StudentData['_extension_data']) {
        $StudentData['_extension_data'] = @{}
    }
    
    # Create the _table_extension structure if not exists
    if (-not $StudentData['_extension_data']['_table_extension']) {
        $StudentData['_extension_data']['_table_extension'] = @{
            '_field' = @()
            'name' = $TableName
        }
    }
    
    # Process each change
    foreach ($change in $ExtensionChanges) {
        if ($change.PowerSchoolAPIField -match $pattern) {
            $fieldName = $matches[1]
            
            # Add the field to the _field array - testing with minimal structure (name/value only)
            $StudentData['_extension_data']['_table_extension']['_field'] += @{
                name = $fieldName
                value = $change.NewValue
            }
            
            Write-Verbose "  Updated $TableName.$fieldName = $($change.NewValue)"
        }
    }
}

# Private helper function to build update payload from changes
function Build-UpdatePayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Changes,
        
        [Parameter(Mandatory = $true)]
        [int]$StudentDCID,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PowerSchoolStudent,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$TemplateMetadata
    )

    # Build update object
    $payload = @{
        students = @{
            student = @{
                client_uid = $StudentDCID.ToString()  # Use DCID as client_uid
                action = "UPDATE"
                id = $StudentDCID
            }
        }
    }

    $studentData = $payload.students.student

    # Process expansion field changes (addresses, demographics, etc.)
    # Pattern: @expansion_name.field_path
    $expansionChanges = $Changes | Where-Object { $_.PowerSchoolAPIField -match '^@([^.]+)\.' }
    
    if ($expansionChanges) {
        # Group by expansion name
        $expansionGroups = $expansionChanges | Group-Object { 
            if ($_.PowerSchoolAPIField -match '^@([^.]+)\.') { $matches[1] }
        }
        
        foreach ($group in $expansionGroups) {
            $expansionName = $group.Name
            Merge-ExpansionFieldChanges -StudentData $studentData `
                -ExpansionChanges $group.Group `
                -PowerSchoolStudent $PowerSchoolStudent `
                -ExpansionName $expansionName
        }
        
        # Remove expansion changes from the main processing loop
        $Changes = $Changes | Where-Object { $_.PowerSchoolAPIField -notmatch '^@' }
    }

    # Process extension field changes (custom tables like studentcorefields)
    # Pattern: extension.table_name.field_name
    $extensionChanges = $Changes | Where-Object { $_.PowerSchoolAPIField -match '^extension\.([^.]+)\.' }
    
    if ($extensionChanges) {
        # Group by extension table name
        $extensionGroups = $extensionChanges | Group-Object { 
            if ($_.PowerSchoolAPIField -match '^extension\.([^.]+)\.') { $matches[1] }
        }
        
        foreach ($group in $extensionGroups) {
            $tableName = $group.Name
            Merge-ExtensionFieldChanges -StudentData $studentData `
                -ExtensionChanges $group.Group `
                -TableName $tableName
        }
        
        # Remove extension changes from the main processing loop
        $Changes = $Changes | Where-Object { $_.PowerSchoolAPIField -notmatch '^extension\.' }
    }

    # Map each remaining change to PowerSchool API field
    foreach ($change in $Changes) {
        $fieldName = $change.Field
        $newValue = $change.NewValue
        
        # Get the PowerSchool API field path - prefer from change object, otherwise lookup
        $psFieldPath = if ($change.PowerSchoolAPIField) {
            $change.PowerSchoolAPIField
        } else {
            Get-PowerSchoolFieldMapping -EntityProperty $fieldName -TemplateMetadata $TemplateMetadata
        }
        
        if (-not $psFieldPath) {
            Write-Warning "No PowerSchool API field mapping found for: $fieldName"
            continue
        }

        # Apply the value based on the field path type
        Set-PowerSchoolFieldValue -StudentData $studentData -FieldPath $psFieldPath -Value $newValue
    }

    return $payload
}

# Private helper function to set a value in the student data structure based on field path
function Set-PowerSchoolFieldValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$StudentData,
        
        [Parameter(Mandatory = $true)]
        [string]$FieldPath,
        
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        $Value
    )

    # Handle different field path types
    if ($FieldPath -match '^name\.(.+)$') {
        # Name field - create nested name object
        if (-not $StudentData['name']) {
            $StudentData['name'] = @{}
        }
        $StudentData['name'][$matches[1]] = $Value
    }
    elseif ($FieldPath -match '^extension\.([^.]+)\.(.+)$') {
        # Extension field - would need proper extension structure
        # This is complex and depends on PowerSchool version
        Write-Warning "Extension field updates not yet implemented: $FieldPath"
    }
    elseif ($FieldPath -match '^@(.+)$') {
        # Expansion fields - handled separately in Build-UpdatePayload via Merge-ExpansionFieldChanges
        # This warning should only appear if expansion fields are used outside of UPDATE operations
        Write-Warning "Expansion field should be handled by Merge-ExpansionFieldChanges: $FieldPath"
    }
    else {
        # Direct field mapping - handle date formatting if needed
        if ($Value -is [DateTime]) {
            # Format dates as ISO string for PowerSchool API
            $StudentData[$FieldPath] = $Value.ToString('yyyy-MM-dd')
        } else {
            $StudentData[$FieldPath] = $Value
        }
    }
}

# Private helper function to invoke student creation API
function Invoke-CreateStudent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )

    try {
        # Ensure connection is valid
        Test-PowerSchoolConnection

        # Get access token
        $accessToken = Get-PowerSchoolAccessToken
        
        $headers = @{
            'Authorization' = "Bearer $accessToken"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }

        $uri = "$script:PowerSchoolBaseUrl/ws/v1/student"

        Write-Verbose "Making API call to create student"
        Write-Verbose "URI: POST $uri"
        Write-Verbose "Headers: Authorization=Bearer [REDACTED], Content-Type=application/json, Accept=application/json"
        Write-Verbose "Payload: $($Payload | ConvertTo-Json -Depth 10 -Compress)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Post `
            -Body $Payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds

        Write-Verbose "API call successful. Response: $($response | ConvertTo-Json -Depth 10 -Compress)"

        # Check if PowerSchool reported an error in the response
        # PowerSchool returns HTTP 200 even for validation errors, with error details in the JSON
        if ($response.results.result.status -eq "ERROR") {
            $errorMsg = $response.results.result.error_message.error
            $errorDetail = "Field: $($errorMsg.field), Code: $($errorMsg.error_code), Description: $($errorMsg.error_description)"
            throw "PowerSchool API validation error: $errorDetail"
        }

        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        Write-Verbose "API call failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Private helper function to invoke student update API
function Invoke-UpdateStudent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DCID,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5
    )

    try {
        # Ensure connection is valid
        Test-PowerSchoolConnection

        # Get access token
        $accessToken = Get-PowerSchoolAccessToken
        
        $headers = @{
            'Authorization' = "Bearer $accessToken"
            'Content-Type' = 'application/json'
            'Accept' = 'application/json'
        }

        # PowerSchool uses POST to /ws/v1/student with action=UPDATE and id in payload
        $uri = "$script:PowerSchoolBaseUrl/ws/v1/student"
        
        # Check if payload contains extension data and add extensions query parameter
        if ($Payload.students.student._extension_data._table_extension) {
            $tableName = $Payload.students.student._extension_data._table_extension.name
            if ($tableName) {
                $uri += "?extensions=$tableName"
                Write-Verbose "Extension table being updated: $tableName"
            }
        }

        Write-Verbose "Making API call to update student DCID: $DCID"
        Write-Verbose "URI: POST $uri"
        Write-Verbose "Headers: Authorization=Bearer [REDACTED], Content-Type=application/json, Accept=application/json"
        Write-Verbose "Payload: $($Payload | ConvertTo-Json -Depth 10 -Compress)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Post `
            -Body $Payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds

        Write-Verbose "API call successful. Response: $($response | ConvertTo-Json -Depth 10 -Compress)"

        # Check if PowerSchool reported an error in the response
        # PowerSchool returns HTTP 200 even for validation errors, with error details in the JSON
        if ($response.results.result.status -eq "ERROR") {
            $errorMsg = $response.results.result.error_message.error
            $errorDetail = "Field: $($errorMsg.field), Code: $($errorMsg.error_code), Description: $($errorMsg.error_description)"
            throw "PowerSchool API validation error: $errorDetail"
        }

        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        Write-Verbose "API call failed: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
