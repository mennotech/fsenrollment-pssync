#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare phone numbers between CSV and PowerSchool person phone records.

.DESCRIPTION
    Performs comparison between CSV phone numbers (PSPhoneNumber) and PowerSchool
    PowerQuery phone objects from com.fsenrollment.dats.person.phone. Returns a list of 
    phone changes including additions, modifications, and deletions.
    
    Compares phone number, type, priority order, preferred status, and SMS capability.

.PARAMETER CsvPhones
    Array of PSPhoneNumber objects from CSV data for a single contact.

.PARAMETER PowerSchoolPhones
    Array of phone objects from PowerSchool PowerQuery (com.fsenrollment.dats.person.phone)
    for a single person.

.PARAMETER ContactIdentifier
    The contact identifier (person_id or ContactID) used for matching. Used in change records.

.OUTPUTS
    PSCustomObject with properties:
    - Added: Array of PSPhoneNumber objects that are new (in CSV, not in PowerSchool)
    - Modified: Array of objects with OldPhone, NewPhone, and Changes properties
    - Removed: Array of PowerSchool phone objects that are no longer in CSV
    - Unchanged: Array of phone numbers that match
    
.NOTES
    This is a private function used internally by Compare-PSContact.
    Maps PSPhoneNumber properties to PowerSchool PowerQuery phone field names.
    
    Phone numbers are matched by the normalized phone number string itself.
    Normalization removes formatting characters (spaces, dashes, parentheses).
    If a match is found, other properties (type, order, preferred, SMS) are compared.
#>
function Compare-ContactPhoneFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [PSPhoneNumber[]]$CsvPhones = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [array]$PowerSchoolPhones = @(),

        [Parameter(Mandatory = $true)]
        [string]$ContactIdentifier
    )

    # Initialize result collections
    $added = [System.Collections.Generic.List[PSCustomObject]]::new()
    $modified = [System.Collections.Generic.List[PSCustomObject]]::new()
    $removed = [System.Collections.Generic.List[PSCustomObject]]::new()
    $unchanged = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Helper function to normalize phone numbers for comparison
    function Normalize-PhoneNumber {
        param([string]$PhoneNumber)
        
        if ([string]::IsNullOrWhiteSpace($PhoneNumber)) {
            return $null
        }
        
        # Remove all formatting characters, keep only digits
        $normalized = $PhoneNumber -replace '[^\d]', ''
        return $normalized
    }

    # Create lookup dictionary for PowerSchool phones by normalized number
    $psLookup = @{}
    foreach ($psPhone in $PowerSchoolPhones) {
        $normalizedPhone = Normalize-PhoneNumber -PhoneNumber $psPhone.phonenumber_phonenumber
        if (-not [string]::IsNullOrWhiteSpace($normalizedPhone)) {
            # Store in lookup - if duplicate phones exist, last one wins
            if ($psLookup.ContainsKey($normalizedPhone)) {
                Write-Warning "Duplicate phone number found in PowerSchool data: $($psPhone.phonenumber_phonenumber) (normalized: $normalizedPhone). Using most recent entry."
            }
            $psLookup[$normalizedPhone] = $psPhone
        }
    }

    # Create lookup dictionary for CSV phones by normalized number
    $csvLookup = @{}
    foreach ($csvPhone in $CsvPhones) {
        $normalizedPhone = Normalize-PhoneNumber -PhoneNumber $csvPhone.PhoneNumber
        if (-not [string]::IsNullOrWhiteSpace($normalizedPhone)) {
            if ($csvLookup.ContainsKey($normalizedPhone)) {
                Write-Warning "Duplicate phone number found in CSV data: $($csvPhone.PhoneNumber) (normalized: $normalizedPhone). Using most recent entry."
            }
            $csvLookup[$normalizedPhone] = $csvPhone
        }
    }

    # Compare CSV phones against PowerSchool
    foreach ($csvPhone in $CsvPhones) {
        $normalizedPhone = Normalize-PhoneNumber -PhoneNumber $csvPhone.PhoneNumber
        
        if ([string]::IsNullOrWhiteSpace($normalizedPhone)) {
            Write-Verbose "Skipping CSV phone with empty number for contact $ContactIdentifier"
            continue
        }

        if ($psLookup.ContainsKey($normalizedPhone)) {
            # Phone exists in PowerSchool - check for changes in other fields
            $psPhone = $psLookup[$normalizedPhone]
            $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

            # Compare IsPreferred (CSV bool vs PS integer 0/1)
            if ($null -ne $csvPhone.IsPreferred) {
                $csvPreferred = if ($csvPhone.IsPreferred) { 1 } else { 0 }
                $psPreferred = if ($null -eq $psPhone.phonenumber_ispreferred) { 0 } else { [int]$psPhone.phonenumber_ispreferred }
                if ($csvPreferred -ne $psPreferred) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'IsPreferred'
                        OldValue = $psPreferred
                        NewValue = $csvPreferred
                    })
                }
            }

            # Compare IsSMS (CSV bool vs PS integer 0/1)
            if ($null -ne $csvPhone.IsSMS) {
                $csvSMS = if ($csvPhone.IsSMS) { 1 } else { 0 }
                $psSMS = if ($null -eq $psPhone.phonenumber_issms) { 0 } else { [int]$psPhone.phonenumber_issms }
                if ($csvSMS -ne $psSMS) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'IsSMS'
                        OldValue = $psSMS
                        NewValue = $csvSMS
                    })
                }
            }

            # Compare PhoneType if present in CSV
            if (-not [string]::IsNullOrWhiteSpace($csvPhone.PhoneType)) {
                $csvType = Normalize-ComparisonValue -Value $csvPhone.PhoneType
                $psType = Normalize-ComparisonValue -Value $psPhone.phonenumber_type
                if ($csvType -ne $psType) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'PhoneType'
                        OldValue = $psType
                        NewValue = $csvType
                    })
                }
            }

            if ($changes.Count -gt 0) {
                $modified.Add([PSCustomObject]@{
                    PhoneNumber = $normalizedPhone
                    DisplayNumber = $csvPhone.PhoneNumber
                    OldPhone = $psPhone
                    NewPhone = $csvPhone
                    Changes = $changes
                })
            } else {
                $unchanged.Add([PSCustomObject]@{
                    PhoneNumber = $normalizedPhone
                })
            }
        } else {
            # Phone is new (not in PowerSchool)
            $added.Add([PSCustomObject]@{
                PhoneNumber = $normalizedPhone
                DisplayNumber = $csvPhone.PhoneNumber
                Phone = $csvPhone
            })
        }
    }

    # Find removed phones (in PowerSchool but not in CSV)
    foreach ($psPhone in $PowerSchoolPhones) {
        $normalizedPhone = Normalize-PhoneNumber -PhoneNumber $psPhone.phonenumber_phonenumber
        
        if ([string]::IsNullOrWhiteSpace($normalizedPhone)) {
            continue
        }

        if (-not $csvLookup.ContainsKey($normalizedPhone)) {
            $removed.Add([PSCustomObject]@{
                PhoneNumber = $normalizedPhone
                DisplayNumber = $psPhone.phonenumber_phonenumber
                Phone = $psPhone
            })
        }
    }

    # Return result object
    return [PSCustomObject]@{
        Added = $added
        Modified = $modified
        Removed = $removed
        Unchanged = $unchanged
    }
}
