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
    Must have New and Updated properties.

.PARAMETER JsonPath
    Path to a JSON file containing the comparison results.
    Alternative to providing Changes parameter.

.PARAMETER Limit
    Maximum number of changes to apply. Useful for testing with live data.
    Default is unlimited (applies all changes).

.PARAMETER WhatIf
    Performs a dry run without making actual changes to PowerSchool.
    Shows what would be changed.

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
    # Dry run to preview changes without applying them
    Submit-PSStudentChange -JsonPath './data/pending_changes.json' -WhatIf

.EXAMPLE
    # Apply changes with custom retry settings
    Submit-PSStudentChange -Changes $changes -MaxRetries 5 -RetryDelaySeconds 10

.NOTES
    Requires an active PowerSchool connection (Connect-PowerSchool must be called first).
    Uses the PowerSchool API v1 endpoints for creating and updating students.
    Only applies changes to student demographic fields, not contact information.
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
                    
                    # Build student payload for API (always build for WhatIf display)
                    $payload = Build-StudentPayload -Student $student
                    
                    if ($PSCmdlet.ShouldProcess("New Student: $matchKey ($($student.FirstName) $($student.LastName))", "Create in PowerSchool")) {
                        if ($WhatIfPreference) {
                            Write-Host "`n=== WHATIF: New Student Creation ===" -ForegroundColor Cyan
                            Write-Host "Student: $matchKey ($($student.FirstName) $($student.LastName))" -ForegroundColor Yellow
                            Write-Host "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/v1/student" -ForegroundColor Gray
                            Write-Host "API Payload:" -ForegroundColor Gray
                            Write-Host ($payload | ConvertTo-Json -Depth 10) -ForegroundColor White
                        } else {
                            Write-Verbose "Creating new student: $matchKey"
                            
                            # Make API call to create student
                            $result = Invoke-CreateStudent -Payload $payload -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                            
                            if ($result.Success) {
                                $script:ApplyResults.NewStudentsApplied++
                                Write-Host "✓ Created new student: $matchKey ($($student.FirstName) $($student.LastName))" -ForegroundColor Green
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
                    $dcid = $psStudent.id
                    if (-not $dcid) {
                        throw "PowerSchool student DCID not found for $matchKey"
                    }
                    
                    # Build update payload (always build for WhatIf display)
                    $payload = Build-UpdatePayload -Changes $changes -StudentDCID $dcid
                    
                    if ($PSCmdlet.ShouldProcess("Student: $matchKey (DCID: $dcid) - $($changes.Count) changes", "Update in PowerSchool")) {
                        if ($WhatIfPreference) {
                            Write-Host "`n=== WHATIF: Student Update ===" -ForegroundColor Cyan
                            Write-Host "Student: $matchKey (DCID: $dcid)" -ForegroundColor Yellow
                            Write-Host "API Endpoint: POST $($script:PowerSchoolBaseUrl)/ws/v1/student" -ForegroundColor Gray
                            Write-Host "Field Changes:" -ForegroundColor Gray
                            foreach ($change in $changes) {
                                Write-Host "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'" -ForegroundColor White
                                if ($change.PowerSchoolAPIField) {
                                    Write-Host "    (API Field: $($change.PowerSchoolAPIField))" -ForegroundColor DarkGray
                                }
                            }
                            Write-Host "API Payload:" -ForegroundColor Gray
                            Write-Host ($payload | ConvertTo-Json -Depth 10) -ForegroundColor White
                        } else {
                            Write-Verbose "Updating student: $matchKey (DCID: $dcid) with $($changes.Count) changes"
                            
                            # Make API call to update student
                            $result = Invoke-UpdateStudent -DCID $dcid -Payload $payload -MaxRetries $MaxRetries -RetryDelaySeconds $RetryDelaySeconds
                            
                            if ($result.Success) {
                                $script:ApplyResults.UpdatedStudentsApplied++
                                Write-Host "✓ Updated student: $matchKey (DCID: $dcid) - $($changes.Count) fields" -ForegroundColor Cyan
                                foreach ($change in $changes) {
                                    Write-Verbose "  $($change.Field): '$($change.OldValue)' -> '$($change.NewValue)'"
                                }
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
        [PSStudent]$Student
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

    # Map PSStudent properties to PowerSchool API fields
    # These are the core demographic fields
    if ($Student.StudentNumber) { $studentData['local_id'] = $Student.StudentNumber }
    if ($Student.SchoolID) { $studentData['school_id'] = $Student.SchoolID }
    if ($Student.GradeLevel) { $studentData['grade_level'] = $Student.GradeLevel }
    if ($Student.Gender) { $studentData['gender'] = $Student.Gender }
    if ($Student.EnrollStatus) { $studentData['enroll_status'] = $Student.EnrollStatus }
    
    # Name fields - these go in nested 'name' object
    $nameData = @{}
    if ($Student.FirstName) { $nameData['first_name'] = $Student.FirstName }
    if ($Student.MiddleName) { $nameData['middle_name'] = $Student.MiddleName }
    if ($Student.LastName) { $nameData['last_name'] = $Student.LastName }
    
    if ($nameData.Count -gt 0) {
        $studentData['name'] = $nameData
    }

    # Date fields
    if ($Student.DOB -and $Student.DOB -is [DateTime]) { 
        $studentData['dob'] = $Student.DOB.ToString('yyyy-MM-dd')
    }
    if ($Student.EntryDate -and $Student.EntryDate -is [DateTime]) { 
        $studentData['entrydate'] = $Student.EntryDate.ToString('yyyy-MM-dd')
    }
    if ($Student.ExitDate -and $Student.ExitDate -is [DateTime]) { 
        $studentData['exitdate'] = $Student.ExitDate.ToString('yyyy-MM-dd')
    }

    # Contact information (phone)
    if ($Student.HomePhone) { $studentData['home_phone'] = $Student.HomePhone }

    # Address fields
    if ($Student.Street -or $Student.City -or $Student.State -or $Student.Zip) {
        if ($Student.Street) { $studentData['street'] = $Student.Street }
        if ($Student.City) { $studentData['city'] = $Student.City }
        if ($Student.State) { $studentData['state'] = $Student.State }
        if ($Student.Zip) { $studentData['zip'] = $Student.Zip }
    }

    # Mailing address fields
    if ($Student.MailingStreet -or $Student.MailingCity -or $Student.MailingState -or $Student.MailingZip) {
        if ($Student.MailingStreet) { $studentData['mailing_street'] = $Student.MailingStreet }
        if ($Student.MailingCity) { $studentData['mailing_city'] = $Student.MailingCity }
        if ($Student.MailingState) { $studentData['mailing_state'] = $Student.MailingState }
        if ($Student.MailingZip) { $studentData['mailing_zip'] = $Student.MailingZip }
    }

    # Extension fields
    if ($Student.FTEID) { 
        # FTEID is typically in an extension table
        # This would need to be mapped to the correct extension structure
        # For now, include it as a note in comments
    }

    if ($Student.FamilyIdent) { $studentData['family_ident'] = $Student.FamilyIdent }
    if ($Student.TransferComment) { $studentData['transfer_comment'] = $Student.TransferComment }

    return $payload
}

# Private helper function to build update payload from changes
function Build-UpdatePayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Changes,
        
        [Parameter(Mandatory = $true)]
        [int]$StudentDCID
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

    # Map each change to PowerSchool API field
    foreach ($change in $Changes) {
        $fieldName = $change.Field
        $newValue = $change.NewValue
        $psFieldPath = $change.PowerSchoolAPIField

        # Handle different field path types
        if ($psFieldPath -and $psFieldPath -match '^name\.(.+)$') {
            # Name field - create nested name object
            if (-not $studentData['name']) {
                $studentData['name'] = @{}
            }
            $studentData['name'][$matches[1]] = $newValue
            continue
        }
        elseif ($psFieldPath -and $psFieldPath -match '^extension\.([^.]+)\.(.+)$') {
            # Extension field - would need proper extension structure
            # This is complex and depends on PowerSchool version
            Write-Warning "Extension field updates not yet implemented: $psFieldPath"
            continue
        }
        elseif ($psFieldPath -and $psFieldPath -match '^@([^.]+)\.(.+)$') {
            # Expansion field - typically read-only
            Write-Warning "Expansion field updates not supported: $psFieldPath"
            continue
        }
        
        # Standard field - map by field name
        $apiFieldName = switch ($fieldName) {
            'StudentNumber' { 'local_id' }
            'SchoolID' { 'school_id' }
            'FirstName' { 
                if (-not $studentData['name']) { $studentData['name'] = @{} }
                $studentData['name']['first_name'] = $newValue
                continue
            }
            'MiddleName' { 
                if (-not $studentData['name']) { $studentData['name'] = @{} }
                $studentData['name']['middle_name'] = $newValue
                continue
            }
            'LastName' { 
                if (-not $studentData['name']) { $studentData['name'] = @{} }
                $studentData['name']['last_name'] = $newValue
                continue
            }
            'GradeLevel' { 'grade_level' }
            'Gender' { 'gender' }
            'DOB' { 
                # Format date as string if it's a DateTime
                if ($newValue -is [DateTime]) {
                    $studentData['dob'] = $newValue.ToString('yyyy-MM-dd')
                } else {
                    $studentData['dob'] = $newValue
                }
                continue
            }
            'EnrollStatus' { 'enroll_status' }
            'EntryDate' { 
                # Format date as string if it's a DateTime
                if ($newValue -is [DateTime]) {
                    $studentData['entrydate'] = $newValue.ToString('yyyy-MM-dd')
                } else {
                    $studentData['entrydate'] = $newValue
                }
                continue
            }
            'ExitDate' { 
                # Format date as string if it's a DateTime
                if ($newValue -is [DateTime]) {
                    $studentData['exitdate'] = $newValue.ToString('yyyy-MM-dd')
                } else {
                    $studentData['exitdate'] = $newValue
                }
                continue
            }
            'HomePhone' { 'home_phone' }
            'Street' { 'street' }
            'City' { 'city' }
            'State' { 'state' }
            'Zip' { 'zip' }
            default { $fieldName.ToLower() }
        }
        
        # Only set if we have a valid API field name and it's not already set
        if ($apiFieldName) {
            $studentData[$apiFieldName] = $newValue
        }
    }

    return $payload
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

        Write-Verbose "POST $uri"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Post `
            -Body $Payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds

        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
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

        Write-Verbose "POST $uri (Update student DCID: $DCID)"
        
        $response = Invoke-PowerSchoolApiRequest `
            -Uri $uri `
            -Headers $headers `
            -Method Post `
            -Body $Payload `
            -MaxRetries $MaxRetries `
            -InitialRetryDelaySeconds $RetryDelaySeconds

        return [PSCustomObject]@{
            Success = $true
            Response = $response
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
