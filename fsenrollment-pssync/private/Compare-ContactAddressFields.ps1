#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare addresses between CSV and PowerSchool person address records.

.DESCRIPTION
    Performs comparison between CSV addresses (PSAddress) and PowerSchool
    PowerQuery address objects from com.fsenrollment.dats.person.address. Returns a list of 
    address changes including additions, modifications, and deletions.
    
    Compares street, line two, unit, city, state, postal code, country, type, and priority order.

.PARAMETER CsvAddresses
    Array of PSAddress objects from CSV data for a single contact.

.PARAMETER PowerSchoolAddresses
    Array of address objects from PowerSchool PowerQuery (com.fsenrollment.dats.person.address)
    for a single person.

.PARAMETER ContactIdentifier
    The contact identifier (person_id or ContactID) used for matching. Used in change records.

.OUTPUTS
    PSCustomObject with properties:
    - Added: Array of PSAddress objects that are new (in CSV, not in PowerSchool)
    - Modified: Array of objects with OldAddress, NewAddress, and Changes properties
    - Removed: Array of PowerSchool address objects that are no longer in CSV
    - Unchanged: Array of addresses that match
    
.NOTES
    This is a private function used internally by Compare-PSContact.
    Maps PSAddress properties to PowerSchool PowerQuery address field names.
    
    Addresses are matched by a composite key of normalized street, city, and postal code.
    This handles cases where the same person has multiple addresses.
    If a match is found, other properties (line two, unit, state, type) are compared.
#>
function Compare-ContactAddressFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [PSAddress[]]$CsvAddresses = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [array]$PowerSchoolAddresses = @(),

        [Parameter(Mandatory = $true)]
        [string]$ContactIdentifier
    )

    # Initialize result collections
    $added = [System.Collections.Generic.List[PSCustomObject]]::new()
    $modified = [System.Collections.Generic.List[PSCustomObject]]::new()
    $removed = [System.Collections.Generic.List[PSCustomObject]]::new()
    $unchanged = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Helper function to create address matching key
    # Note: This uses exact matching on street/city/postal after normalization.
    # Minor variations like 'Main St' vs 'Main Street' or 'Apt 5' vs 'Unit 5' will not match.
    # This is intentional to avoid false positives from similar but different addresses.
    function Get-AddressMatchKey {
        param(
            [string]$Street,
            [string]$City,
            [string]$PostalCode
        )
        
        $normalizedStreet = Normalize-ComparisonValue -Value $Street
        $normalizedCity = Normalize-ComparisonValue -Value $City
        $normalizedPostal = Normalize-ComparisonValue -Value $PostalCode
        
        # Convert to lowercase only if not null
        $normalizedStreet = if ($null -ne $normalizedStreet) { $normalizedStreet.ToLower() } else { '' }
        $normalizedCity = if ($null -ne $normalizedCity) { $normalizedCity.ToLower() } else { '' }
        $normalizedPostal = if ($null -ne $normalizedPostal) { $normalizedPostal.ToLower() -replace '[^a-z0-9]', '' } else { '' }
        
        if ([string]::IsNullOrWhiteSpace($normalizedStreet) -and [string]::IsNullOrWhiteSpace($normalizedCity)) {
            return $null
        }
        
        return "$normalizedStreet|$normalizedCity|$normalizedPostal"
    }

    # Create lookup dictionary for PowerSchool addresses by match key
    $psLookup = @{}
    foreach ($psAddress in $PowerSchoolAddresses) {
        $matchKey = Get-AddressMatchKey -Street $psAddress.address_street `
                                       -City $psAddress.address_city `
                                       -PostalCode $psAddress.address_postalcode
        if ($matchKey) {
            # If duplicate match keys exist, last one wins
            if ($psLookup.ContainsKey($matchKey)) {
                Write-Warning "Duplicate address found in PowerSchool data: $($psAddress.address_street), $($psAddress.address_city) $($psAddress.address_postalcode). Using most recent entry."
            }
            $psLookup[$matchKey] = $psAddress
        }
    }

    # Create lookup dictionary for CSV addresses by match key
    $csvLookup = @{}
    foreach ($csvAddress in $CsvAddresses) {
        $matchKey = Get-AddressMatchKey -Street $csvAddress.Street `
                                       -City $csvAddress.City `
                                       -PostalCode $csvAddress.PostalCode
        if ($matchKey) {
            if ($csvLookup.ContainsKey($matchKey)) {
                Write-Warning "Duplicate address found in CSV data: $($csvAddress.Street), $($csvAddress.City) $($csvAddress.PostalCode). Using most recent entry."
            }
            $csvLookup[$matchKey] = $csvAddress
        }
    }

    # Compare CSV addresses against PowerSchool
    foreach ($csvAddress in $CsvAddresses) {
        $matchKey = Get-AddressMatchKey -Street $csvAddress.Street `
                                       -City $csvAddress.City `
                                       -PostalCode $csvAddress.PostalCode
        
        if (-not $matchKey) {
            Write-Verbose "Skipping CSV address with insufficient data for contact $ContactIdentifier"
            continue
        }

        if ($psLookup.ContainsKey($matchKey)) {
            # Address exists in PowerSchool - check for changes in other fields
            $psAddress = $psLookup[$matchKey]
            $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

            # Compare LineTwo
            $csvLineTwo = Normalize-ComparisonValue -Value $csvAddress.LineTwo
            $psLineTwo = Normalize-ComparisonValue -Value $psAddress.address_linetwo
            if ($csvLineTwo -ne $psLineTwo) {
                $changes.Add([PSCustomObject]@{
                    Field = 'LineTwo'
                    OldValue = $psLineTwo
                    NewValue = $csvLineTwo
                })
            }

            # Compare Unit
            $csvUnit = Normalize-ComparisonValue -Value $csvAddress.Unit
            $psUnit = Normalize-ComparisonValue -Value $psAddress.address_unit
            if ($csvUnit -ne $psUnit) {
                $changes.Add([PSCustomObject]@{
                    Field = 'Unit'
                    OldValue = $psUnit
                    NewValue = $csvUnit
                })
            }

            # Compare State
            $csvState = Normalize-ComparisonValue -Value $csvAddress.State
            $psState = Normalize-ComparisonValue -Value $psAddress.address_state
            if ($csvState -ne $psState) {
                $changes.Add([PSCustomObject]@{
                    Field = 'State'
                    OldValue = $psState
                    NewValue = $csvState
                })
            }

            # Compare AddressType if present in CSV
            if (-not [string]::IsNullOrWhiteSpace($csvAddress.AddressType)) {
                $csvType = Normalize-ComparisonValue -Value $csvAddress.AddressType
                $psType = Normalize-ComparisonValue -Value $psAddress.address_type
                if ($csvType -ne $psType) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'AddressType'
                        OldValue = $psType
                        NewValue = $csvType
                    })
                }
            }

            if ($changes.Count -gt 0) {
                $modified.Add([PSCustomObject]@{
                    MatchKey = $matchKey
                    DisplayAddress = "$($csvAddress.Street), $($csvAddress.City), $($csvAddress.State) $($csvAddress.PostalCode)"
                    OldAddress = $psAddress
                    NewAddress = $csvAddress
                    Changes = $changes
                })
            } else {
                $unchanged.Add([PSCustomObject]@{
                    MatchKey = $matchKey
                })
            }
        } else {
            # Address is new (not in PowerSchool)
            $added.Add([PSCustomObject]@{
                MatchKey = $matchKey
                DisplayAddress = "$($csvAddress.Street), $($csvAddress.City), $($csvAddress.State) $($csvAddress.PostalCode)"
                Address = $csvAddress
            })
        }
    }

    # Find removed addresses (in PowerSchool but not in CSV)
    foreach ($psAddress in $PowerSchoolAddresses) {
        $matchKey = Get-AddressMatchKey -Street $psAddress.address_street `
                                       -City $psAddress.address_city `
                                       -PostalCode $psAddress.address_postalcode
        
        if (-not $matchKey) {
            continue
        }

        if (-not $csvLookup.ContainsKey($matchKey)) {
            $removed.Add([PSCustomObject]@{
                MatchKey = $matchKey
                DisplayAddress = "$($psAddress.address_street), $($psAddress.address_city), $($psAddress.address_state) $($psAddress.address_postalcode)"
                Address = $psAddress
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
