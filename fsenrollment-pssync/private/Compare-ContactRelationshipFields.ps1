#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to compare relationships between CSV and PowerSchool person relationship records.

.DESCRIPTION
    Performs comparison between CSV relationships (PSStudentContactRelationship) and PowerSchool
    PowerQuery relationship objects from com.fsenrollment.dats.person.relationship. Returns a list of 
    relationship changes including additions, modifications, and deletions.
    
    Compares relationship type, priority order, and various relationship flags (custody, emergency, lives with, etc.).

.PARAMETER CsvRelationships
    Array of PSStudentContactRelationship objects from CSV data for a single contact.

.PARAMETER PowerSchoolRelationships
    Array of relationship objects from PowerSchool PowerQuery (com.fsenrollment.dats.person.relationship)
    for a single person.

.PARAMETER ContactIdentifier
    The contact identifier (person_id or ContactID) used for matching. Used in change records.

.OUTPUTS
    PSCustomObject with properties:
    - Added: Array of PSStudentContactRelationship objects that are new (in CSV, not in PowerSchool)
    - Modified: Array of objects with OldRelationship, NewRelationship, and Changes properties
    - Removed: Array of PowerSchool relationship objects that are no longer in CSV
    - Unchanged: Array of relationships that match
    
.NOTES
    This is a private function used internally by Compare-PSContact.
    Maps PSStudentContactRelationship properties to PowerSchool PowerQuery relationship field names.
    
    Relationships are matched by the combination of person and student (ContactIdentifier + StudentNumber).
    If a match is found, other properties (priority, flags, type, note) are compared.
#>
function Compare-ContactRelationshipFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [PSStudentContactRelationship[]]$CsvRelationships = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [array]$PowerSchoolRelationships = @(),

        [Parameter(Mandatory = $true)]
        [string]$ContactIdentifier
    )

    # Initialize result collections
    $added = [System.Collections.Generic.List[PSCustomObject]]::new()
    $modified = [System.Collections.Generic.List[PSCustomObject]]::new()
    $removed = [System.Collections.Generic.List[PSCustomObject]]::new()
    $unchanged = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Helper function to create relationship matching key (person + student)
    function Get-RelationshipMatchKey {
        param([string]$StudentNumber)
        
        if ([string]::IsNullOrWhiteSpace($StudentNumber)) {
            return $null
        }
        
        return $StudentNumber.Trim()
    }

    # Create lookup dictionary for PowerSchool relationships by student number
    $psLookup = @{}
    foreach ($psRel in $PowerSchoolRelationships) {
        $matchKey = Get-RelationshipMatchKey -StudentNumber $psRel.student_student_number
        if ($matchKey) {
            # Store in lookup - if duplicate student relationships exist, last one wins
            if ($psLookup.ContainsKey($matchKey)) {
                Write-Warning "Duplicate relationship found in PowerSchool data for student: $($psRel.student_student_number). Using most recent entry."
            }
            $psLookup[$matchKey] = $psRel
        }
    }

    # Create lookup dictionary for CSV relationships by student number
    $csvLookup = @{}
    foreach ($csvRel in $CsvRelationships) {
        $matchKey = Get-RelationshipMatchKey -StudentNumber $csvRel.StudentNumber
        if ($matchKey) {
            if ($csvLookup.ContainsKey($matchKey)) {
                Write-Warning "Duplicate relationship found in CSV data for student: $($csvRel.StudentNumber). Using most recent entry."
            }
            $csvLookup[$matchKey] = $csvRel
        }
    }

    # Compare CSV relationships against PowerSchool
    foreach ($csvRel in $CsvRelationships) {
        $matchKey = Get-RelationshipMatchKey -StudentNumber $csvRel.StudentNumber
        
        if (-not $matchKey) {
            Write-Verbose "Skipping CSV relationship with empty student number for contact $ContactIdentifier"
            continue
        }

        if ($psLookup.ContainsKey($matchKey)) {
            # Relationship exists in PowerSchool - check for changes in other fields
            $psRel = $psLookup[$matchKey]
            $changes = [System.Collections.Generic.List[PSCustomObject]]::new()

            # Compare ContactPriorityOrder
            if ($null -ne $csvRel.ContactPriorityOrder) {
                $csvPriority = [int]$csvRel.ContactPriorityOrder
                $psPriority = [int]$psRel.relationship_priority_order
                if ($csvPriority -ne $psPriority) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'ContactPriorityOrder'
                        OldValue = $psPriority
                        NewValue = $csvPriority
                    })
                }
            }

            # Compare RelationshipType
            if (-not [string]::IsNullOrWhiteSpace($csvRel.RelationshipType)) {
                $csvType = Normalize-ComparisonValue -Value $csvRel.RelationshipType
                $psType = Normalize-ComparisonValue -Value $psRel.relationship_relationship_code
                if ($csvType -ne $psType) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'RelationshipType'
                        OldValue = $psType
                        NewValue = $csvType
                    })
                }
            }

            # Compare RelationshipNote
            $csvNote = Normalize-ComparisonValue -Value $csvRel.RelationshipNote
            $psNote = Normalize-ComparisonValue -Value $psRel.relationship_relationship_note
            if ($csvNote -ne $psNote) {
                $changes.Add([PSCustomObject]@{
                    Field = 'RelationshipNote'
                    OldValue = $psNote
                    NewValue = $csvNote
                })
            }

            # Compare HasCustody (CSV bool vs PS integer 0/1)
            if ($null -ne $csvRel.HasCustody) {
                $csvCustody = if ($csvRel.HasCustody) { 1 } else { 0 }
                $psCustody = [int]$psRel.relationship_iscustodial
                if ($csvCustody -ne $psCustody) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'HasCustody'
                        OldValue = $psCustody
                        NewValue = $csvCustody
                    })
                }
            }

            # Compare LivesWith (CSV bool vs PS integer 0/1)
            if ($null -ne $csvRel.LivesWith) {
                $csvLivesWith = if ($csvRel.LivesWith) { 1 } else { 0 }
                $psLivesWith = [int]$psRel.relationship_liveswith
                if ($csvLivesWith -ne $psLivesWith) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'LivesWith'
                        OldValue = $psLivesWith
                        NewValue = $csvLivesWith
                    })
                }
            }

            # Compare AllowSchoolPickup (CSV bool vs PS integer 0/1)
            if ($null -ne $csvRel.AllowSchoolPickup) {
                $csvPickup = if ($csvRel.AllowSchoolPickup) { 1 } else { 0 }
                $psPickup = [int]$psRel.relationship_schoolpickup
                if ($csvPickup -ne $psPickup) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'AllowSchoolPickup'
                        OldValue = $psPickup
                        NewValue = $csvPickup
                    })
                }
            }

            # Compare IsEmergencyContact (CSV bool vs PS integer 0/1)
            if ($null -ne $csvRel.IsEmergencyContact) {
                $csvEmergency = if ($csvRel.IsEmergencyContact) { 1 } else { 0 }
                $psEmergency = [int]$psRel.relationship_isemergency
                if ($csvEmergency -ne $psEmergency) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'IsEmergencyContact'
                        OldValue = $psEmergency
                        NewValue = $csvEmergency
                    })
                }
            }

            # Compare ReceivesMail (CSV bool vs PS integer 0/1)
            if ($null -ne $csvRel.ReceivesMail) {
                $csvMail = if ($csvRel.ReceivesMail) { 1 } else { 0 }
                $psMail = [int]$psRel.relationship_receivesmail
                if ($csvMail -ne $psMail) {
                    $changes.Add([PSCustomObject]@{
                        Field = 'ReceivesMail'
                        OldValue = $psMail
                        NewValue = $csvMail
                    })
                }
            }

            if ($changes.Count -gt 0) {
                $modified.Add([PSCustomObject]@{
                    StudentNumber = $matchKey
                    OldRelationship = $psRel
                    NewRelationship = $csvRel
                    Changes = $changes
                })
            } else {
                $unchanged.Add([PSCustomObject]@{
                    StudentNumber = $matchKey
                })
            }
        } else {
            # Relationship is new (not in PowerSchool)
            $added.Add([PSCustomObject]@{
                StudentNumber = $matchKey
                Relationship = $csvRel
            })
        }
    }

    # Find removed relationships (in PowerSchool but not in CSV)
    foreach ($psRel in $PowerSchoolRelationships) {
        $matchKey = Get-RelationshipMatchKey -StudentNumber $psRel.student_student_number
        
        if (-not $matchKey) {
            continue
        }

        if (-not $csvLookup.ContainsKey($matchKey)) {
            $removed.Add([PSCustomObject]@{
                StudentNumber = $matchKey
                Relationship = $psRel
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
