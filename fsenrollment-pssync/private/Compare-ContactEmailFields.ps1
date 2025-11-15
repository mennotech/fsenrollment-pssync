#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare email addresses between CSV and PowerSchool person email records.

.DESCRIPTION
    Performs comparison between CSV email addresses (PSEmailAddress) and PowerSchool
    PowerQuery email objects from com.fsenrollment.dats.person.email. Returns a list of 
    email changes including additions, modifications, and deletions.
    
    Compares email address, type, priority order, and primary status.

.PARAMETER CsvEmails
    Array of PSEmailAddress objects from CSV data for a single contact.

.PARAMETER PowerSchoolEmails
    Array of email objects from PowerSchool PowerQuery (com.fsenrollment.dats.person.email)
    for a single person.

.PARAMETER ContactIdentifier
    The contact identifier (person_id or ContactID) used for matching. Used in change records.

.OUTPUTS
    PSCustomObject with properties:
    - Added: Array of PSEmailAddress objects that are new (in CSV, not in PowerSchool)
    - Modified: Array of objects with OldEmail, NewEmail, and Changes properties
    - Removed: Array of PowerSchool email objects that are no longer in CSV
    - Unchanged: Array of email addresses that match
    
.NOTES
    This is a private function used internally by Compare-PSContact.
    Maps PSEmailAddress properties to PowerSchool PowerQuery email field names.
    
    Email addresses are matched by the email address string itself (normalized).
    If a match is found, other properties (type, order, primary) are compared.
#>
function Compare-ContactEmailFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [PSEmailAddress[]]$CsvEmails = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [array]$PowerSchoolEmails = @(),

        [Parameter(Mandatory = $true)]
        [string]$ContactIdentifier
    )

    # Initialize result collections
    $added = [System.Collections.Generic.List[PSCustomObject]]::new()
    $modified = [System.Collections.Generic.List[PSCustomObject]]::new()
    $removed = [System.Collections.Generic.List[PSCustomObject]]::new()
    $unchanged = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Create lookup dictionary for PowerSchool emails by normalized email address
    $psLookup = @{}
    foreach ($psEmail in $PowerSchoolEmails) {
        $normalizedEmail = (Normalize-ComparisonValue -Value $psEmail.emailaddress_emailaddress).ToLower()
        if (-not [string]::IsNullOrWhiteSpace($normalizedEmail)) {
            # Store in lookup - if duplicate emails exist, last one wins
            if ($psLookup.ContainsKey($normalizedEmail)) {
                Write-Warning "Duplicate email address found in PowerSchool data: $($psEmail.emailaddress_emailaddress) (normalized: $normalizedEmail). Using most recent entry."
            }
            $psLookup[$normalizedEmail] = $psEmail
        }
    }

    # Create lookup dictionary for CSV emails by normalized email address
    $csvLookup = @{}
    foreach ($csvEmail in $CsvEmails) {
        $normalizedEmail = (Normalize-ComparisonValue -Value $csvEmail.EmailAddress).ToLower()
        if (-not [string]::IsNullOrWhiteSpace($normalizedEmail)) {
            if ($csvLookup.ContainsKey($normalizedEmail)) {
                Write-Warning "Duplicate email address found in CSV data: $($csvEmail.EmailAddress) (normalized: $normalizedEmail). Using most recent entry."
            }
            $csvLookup[$normalizedEmail] = $csvEmail
        }
    }

    # Compare CSV emails against PowerSchool
    foreach ($csvEmail in $CsvEmails) {
        $normalizedEmail = (Normalize-ComparisonValue -Value $csvEmail.EmailAddress).ToLower()
        
        if ([string]::IsNullOrWhiteSpace($normalizedEmail)) {
            Write-Verbose "Skipping CSV email with empty address for contact $ContactIdentifier"
            continue
        }

        if ($psLookup.ContainsKey($normalizedEmail)) {
            # Email exists in PowerSchool - check for changes in other fields
            $psEmail = $psLookup[$normalizedEmail]
            $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

            # Compare IsPrimary (CSV bool vs PS integer 0/1)
            $csvPrimary = if ($csvEmail.IsPrimary) { 1 } else { 0 }
            $psPrimary = [int]$psEmail.emailaddress_isprimary
            if ($csvPrimary -ne $psPrimary) {
                $changes.Add([PSCustomObject]@{
                    Field = 'IsPrimary'
                    OldValue = $psPrimary
                    NewValue = $csvPrimary
                })
            }

            # Note: EmailAddressID and type are not typically compared as they may not be in CSV
            # If needed, these comparisons can be added based on CSV template structure

            if ($changes.Count -gt 0) {
                $modified.Add([PSCustomObject]@{
                    EmailAddress = $normalizedEmail
                    OldEmail = $psEmail
                    NewEmail = $csvEmail
                    Changes = $changes
                })
            } else {
                $unchanged.Add([PSCustomObject]@{
                    EmailAddress = $normalizedEmail
                })
            }
        } else {
            # Email is new (not in PowerSchool)
            $added.Add([PSCustomObject]@{
                EmailAddress = $normalizedEmail
                Email = $csvEmail
            })
        }
    }

    # Find removed emails (in PowerSchool but not in CSV)
    foreach ($psEmail in $PowerSchoolEmails) {
        $normalizedEmail = (Normalize-ComparisonValue -Value $psEmail.emailaddress_emailaddress).ToLower()
        
        if ([string]::IsNullOrWhiteSpace($normalizedEmail)) {
            continue
        }

        if (-not $csvLookup.ContainsKey($normalizedEmail)) {
            $removed.Add([PSCustomObject]@{
                EmailAddress = $normalizedEmail
                Email = $psEmail
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
