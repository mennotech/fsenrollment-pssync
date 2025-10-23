#Requires -Version 7.0

<#
.SYNOPSIS
    Converts parent CSV data to structured parent-student relationship data for PowerSchool.

.DESCRIPTION
    Processes Final Site Enrollment parent CSV export which contains multiple row types:
    1. Parent demographic records (with contact info)
    2. Additional phone number records
    3. Student relationship records
    
    The function groups these by contact identifier and creates structured objects with:
    - Parent contact information
    - Array of phone numbers
    - Array of student relationships

.PARAMETER CsvData
    The parent CSV data to process. Can be an array of PSCustomObject from Import-Csv.

.PARAMETER Template
    The normalization template hashtable. If not provided, loads the default
    'fs_powerschool_nonapi_report' template.

.PARAMETER TemplateName
    The name of the template to load if Template parameter is not provided.
    Default is 'fs_powerschool_nonapi_report'.

.OUTPUTS
    System.Object
    Returns an object with three properties:
    - Contacts: Array of parent/contact demographic records
    - PhoneNumbers: Array of phone number records linked to contacts
    - Relationships: Array of student relationship records

.EXAMPLE
    $parents = Import-Csv './data/parents.csv'
    $structured = ConvertTo-ParentStudentRelationships -CsvData $parents
    
.EXAMPLE
    $parents = Import-Csv './data/parents.csv'
    $structured = ConvertTo-ParentStudentRelationships -CsvData $parents -Verbose
    
    # Access the different components
    $structured.Contacts | Format-Table
    $structured.PhoneNumbers | Format-Table
    $structured.Relationships | Format-Table

.NOTES
    The function detects row types by checking for populated fields:
    - Demographic rows: Have name fields (First Name, Last Name, etc.)
    - Phone rows: Have phone number but no name fields
    - Relationship rows: Have studentNumber populated
#>
function ConvertTo-ParentStudentRelationships {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSCustomObject[]]$CsvData,

        [Parameter(Mandatory = $false)]
        [hashtable]$Template,

        [Parameter(Mandatory = $false)]
        [string]$TemplateName = 'fs_powerschool_nonapi_report'
    )

    begin {
        Write-Verbose "Processing parent CSV data into structured parent-student relationships"

        if (-not $Template) {
            Write-Verbose "Loading template: $TemplateName"
            $Template = Get-CsvNormalizationTemplate -TemplateName $TemplateName
        }

        if (-not $Template.ContainsKey('Parents')) {
            throw "Template does not contain mappings for Parents data type"
        }

        $fieldMappings = $Template['Parents']
        
        # Initialize collections
        $contacts = [System.Collections.Generic.List[PSCustomObject]]::new()
        $phoneNumbers = [System.Collections.Generic.List[PSCustomObject]]::new()
        $relationships = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Track processed contacts
        $processedContacts = @{}
    }

    process {
        foreach ($row in $CsvData) {
            # Get the contact identifier
            $contactId = $null
            foreach ($column in $fieldMappings['id']) {
                if ($row.PSObject.Properties.Name -contains $column) {
                    $contactId = $row.$column
                    if ($contactId) { break }
                }
            }

            if (-not $contactId) {
                Write-Warning "Row missing contact identifier, skipping"
                continue
            }

            # Determine row type by checking for key fields
            $hasStudentNumber = $false
            $hasName = $false
            $hasPhone = $false

            # Check for student number (relationship row)
            foreach ($column in $fieldMappings['student_number']) {
                if ($row.PSObject.Properties.Name -contains $column -and $row.$column) {
                    $hasStudentNumber = $true
                    break
                }
            }

            # Check for name fields (demographic row)
            foreach ($column in $fieldMappings['first_name']) {
                if ($row.PSObject.Properties.Name -contains $column -and $row.$column) {
                    $hasName = $true
                    break
                }
            }
            if (-not $hasName) {
                foreach ($column in $fieldMappings['last_name']) {
                    if ($row.PSObject.Properties.Name -contains $column -and $row.$column) {
                        $hasName = $true
                        break
                    }
                }
            }

            # Check for phone number (phone row or demographic row)
            foreach ($column in $fieldMappings['phone_number']) {
                if ($row.PSObject.Properties.Name -contains $column -and $row.$column) {
                    $hasPhone = $true
                    break
                }
            }

            # Process based on row type
            if ($hasStudentNumber) {
                # This is a relationship row
                $relationship = [ordered]@{
                    contact_id = $contactId
                }

                # Map relationship fields
                $relationshipFields = @(
                    'student_number', 'relationship_type', 'relationship_note',
                    'legal_guardian', 'has_custody', 'lives_with',
                    'allow_school_pickup', 'is_emergency_contact', 'receives_mailings',
                    'contact_priority_order'
                )

                foreach ($field in $relationshipFields) {
                    $value = $null
                    foreach ($column in $fieldMappings[$field]) {
                        if ($row.PSObject.Properties.Name -contains $column) {
                            $value = $row.$column
                            if ($value) { break }
                        }
                    }

                    # Convert data types for boolean fields
                    if ($field -in @('legal_guardian', 'has_custody', 'lives_with', 
                                     'allow_school_pickup', 'is_emergency_contact', 'receives_mailings')) {
                        $value = ConvertDataType -Value $value -TargetType 'bool' -Transformations $Template.Transformations
                    }
                    elseif ($field -eq 'contact_priority_order') {
                        $value = ConvertDataType -Value $value -TargetType 'int' -Transformations $Template.Transformations
                    }

                    $relationship[$field] = $value
                }

                $relationships.Add([PSCustomObject]$relationship)
                Write-Verbose "Added relationship: Contact $contactId -> Student $($relationship.student_number)"
            }
            elseif ($hasName) {
                # This is a demographic row (main parent record)
                if ($processedContacts.ContainsKey($contactId)) {
                    Write-Verbose "Contact $contactId already processed, skipping duplicate demographic row"
                    continue
                }

                $contact = [ordered]@{
                    id = $contactId
                }

                # Map contact demographic fields
                $contactFields = @(
                    'contact_id', 'prefix', 'first_name', 'middle_name', 'last_name',
                    'suffix', 'gender', 'employer', 'is_active', 'email',
                    'address_type', 'street', 'street_line_two', 'unit',
                    'city', 'state', 'postal_code'
                )

                foreach ($field in $contactFields) {
                    $value = $null
                    foreach ($column in $fieldMappings[$field]) {
                        if ($row.PSObject.Properties.Name -contains $column) {
                            $value = $row.$column
                            if ($value) { break }
                        }
                    }

                    # Convert data types
                    if ($field -eq 'is_active') {
                        $value = ConvertDataType -Value $value -TargetType 'bool' -Transformations $Template.Transformations
                    }

                    $contact[$field] = $value
                }

                $contacts.Add([PSCustomObject]$contact)
                $processedContacts[$contactId] = $true
                Write-Verbose "Added contact: $contactId - $($contact.first_name) $($contact.last_name)"

                # If this row also has a phone number, add it
                if ($hasPhone) {
                    $phone = [ordered]@{
                        contact_id = $contactId
                    }

                    $phoneFields = @('phone_type', 'phone_number', 'is_preferred_phone', 'is_sms')
                    foreach ($field in $phoneFields) {
                        $value = $null
                        foreach ($column in $fieldMappings[$field]) {
                            if ($row.PSObject.Properties.Name -contains $column) {
                                $value = $row.$column
                                if ($value) { break }
                            }
                        }

                        # Convert data types
                        if ($field -in @('is_preferred_phone', 'is_sms')) {
                            $value = ConvertDataType -Value $value -TargetType 'bool' -Transformations $Template.Transformations
                        }

                        $phone[$field] = $value
                    }

                    $phoneNumbers.Add([PSCustomObject]$phone)
                    Write-Verbose "Added phone for contact ${contactId}: $($phone.phone_type) - $($phone.phone_number)"
                }
            }
            elseif ($hasPhone) {
                # This is an additional phone number row
                $phone = [ordered]@{
                    contact_id = $contactId
                }

                $phoneFields = @('phone_type', 'phone_number', 'is_preferred_phone', 'is_sms')
                foreach ($field in $phoneFields) {
                    $value = $null
                    foreach ($column in $fieldMappings[$field]) {
                        if ($row.PSObject.Properties.Name -contains $column) {
                            $value = $row.$column
                            if ($value) { break }
                        }
                    }

                    # Convert data types
                    if ($field -in @('is_preferred_phone', 'is_sms')) {
                        $value = ConvertDataType -Value $value -TargetType 'bool' -Transformations $Template.Transformations
                    }

                    $phone[$field] = $value
                }

                $phoneNumbers.Add([PSCustomObject]$phone)
                Write-Verbose "Added additional phone for contact ${contactId}: $($phone.phone_type) - $($phone.phone_number)"
            }
        }
    }

    end {
        Write-Verbose "Processing complete: $($contacts.Count) contacts, $($phoneNumbers.Count) phone numbers, $($relationships.Count) relationships"

        return [PSCustomObject]@{
            Contacts = $contacts.ToArray()
            PhoneNumbers = $phoneNumbers.ToArray()
            Relationships = $relationships.ToArray()
        }
    }
}

<#
.SYNOPSIS
    Helper function to convert data types.

.DESCRIPTION
    Internal helper function that converts string values from CSV to appropriate
    data types based on template configuration.

.PARAMETER Value
    The value to convert.

.PARAMETER TargetType
    The target data type (e.g., 'int', 'bool', 'date').

.PARAMETER Transformations
    Hashtable containing transformation rules from the template.

.OUTPUTS
    System.Object
    Returns the converted value in the appropriate type.

.NOTES
    This is a private helper function used by ConvertTo-ParentStudentRelationships.
#>
function ConvertDataType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value,

        [Parameter(Mandatory = $false)]
        [string]$TargetType,

        [Parameter(Mandatory = $false)]
        [hashtable]$Transformations = @{}
    )

    if ($null -eq $Value -or $Value -eq '') {
        return $null
    }

    $stringValue = $Value.ToString().Trim()

    if ([string]::IsNullOrWhiteSpace($stringValue)) {
        return $null
    }

    switch ($TargetType) {
        'int' {
            $intValue = 0
            if ([int]::TryParse($stringValue, [ref]$intValue)) {
                return $intValue
            }
            return $null
        }
        'bool' {
            $booleanTrueValues = if ($Transformations.ContainsKey('BooleanTrue')) {
                $Transformations.BooleanTrue
            } else {
                @('1', 'true', 'yes', 'y')
            }

            $booleanFalseValues = if ($Transformations.ContainsKey('BooleanFalse')) {
                $Transformations.BooleanFalse
            } else {
                @('0', 'false', 'no', 'n', '')
            }

            if ($booleanTrueValues -contains $stringValue.ToLower()) {
                return $true
            }
            elseif ($booleanFalseValues -contains $stringValue.ToLower()) {
                return $false
            }
            return $null
        }
        'date' {
            $dateValue = Get-Date
            if ([datetime]::TryParse($stringValue, [ref]$dateValue)) {
                return $dateValue
            }
            return $null
        }
        default {
            return $stringValue
        }
    }
}
