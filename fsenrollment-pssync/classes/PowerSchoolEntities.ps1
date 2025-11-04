#Requires -Version 7.0

<#
.SYNOPSIS
    PowerSchool entity classes for normalized data structures.

.DESCRIPTION
    Defines classes representing PowerSchool data entities that are used
    to normalize CSV data from various sources before syncing to PowerSchool.
#>

# Student entity representing a PowerSchool student record
class PSStudent {
    [string]$StudentNumber
    [string]$SchoolID
    [string]$FirstName
    [string]$MiddleName
    [string]$LastName
    [int]$GradeLevel
    [string]$HomePhone
    [string]$Gender
    [datetime]$DOB
    [string]$FTEID
    [int]$EnrollStatus
    [datetime]$EntryDate
    [datetime]$ExitDate
    [string]$Street
    [string]$City
    [string]$State
    [string]$Zip
    [string]$MailingStreet
    [string]$MailingCity
    [string]$MailingState
    [string]$MailingZip
    [int]$SchedNextYearGrade
    [string]$NextSchool
    [int]$SchedScheduled
    [int]$SchedYearOfGraduation
    [string]$TransferComment
    [string]$FamilyIdent

    PSStudent() {}
}

# Contact entity representing a PowerSchool contact (parent/guardian)
class PSContact {
    [string]$ContactIdentifier
    [string]$ContactID
    [string]$Prefix
    [string]$FirstName
    [string]$MiddleName
    [string]$LastName
    [string]$Suffix
    [string]$Gender
    [string]$Employer
    [bool]$IsActive

    PSContact() {}
}

# Email address entity
class PSEmailAddress {
    [string]$ContactIdentifier
    [string]$EmailAddress
    [string]$EmailAddressID
    [bool]$IsPrimary

    PSEmailAddress() {}
}

# Phone number entity
class PSPhoneNumber {
    [string]$ContactIdentifier
    [int]$PriorityOrder
    [string]$PhoneType
    [string]$PhoneNumber
    [bool]$IsPreferred
    [bool]$IsSMS
    [string]$PhoneNumberID

    PSPhoneNumber() {}
}

# Address entity
class PSAddress {
    [string]$ContactIdentifier
    [string]$AddressType
    [string]$Street
    [string]$LineTwo
    [string]$Unit
    [string]$City
    [string]$State
    [string]$PostalCode
    [string]$AddressID
    [int]$PriorityOrder

    PSAddress() {}
}

# Student-Contact relationship entity
class PSStudentContactRelationship {
    [string]$ContactIdentifier
    [string]$StudentNumber
    [string]$StudentName
    [int]$ContactPriorityOrder
    [string]$StudentContactID
    [string]$StudentContactDetailID
    [string]$RelationshipType
    [string]$RelationshipNote
    [bool]$IsLegalGuardian
    [bool]$HasCustody
    [bool]$LivesWith
    [bool]$AllowSchoolPickup
    [bool]$IsEmergencyContact
    [bool]$ReceivesMail

    PSStudentContactRelationship() {}
}

# Container class for all normalized data from a CSV import
class PSNormalizedData {
    [System.Collections.Generic.List[PSStudent]]$Students
    [System.Collections.Generic.List[PSContact]]$Contacts
    [System.Collections.Generic.List[PSEmailAddress]]$EmailAddresses
    [System.Collections.Generic.List[PSPhoneNumber]]$PhoneNumbers
    [System.Collections.Generic.List[PSAddress]]$Addresses
    [System.Collections.Generic.List[PSStudentContactRelationship]]$Relationships
    [hashtable]$TemplateMetadata

    PSNormalizedData() {
        $this.Students = [System.Collections.Generic.List[PSStudent]]::new()
        $this.Contacts = [System.Collections.Generic.List[PSContact]]::new()
        $this.EmailAddresses = [System.Collections.Generic.List[PSEmailAddress]]::new()
        $this.PhoneNumbers = [System.Collections.Generic.List[PSPhoneNumber]]::new()
        $this.Addresses = [System.Collections.Generic.List[PSAddress]]::new()
        $this.Relationships = [System.Collections.Generic.List[PSStudentContactRelationship]]::new()
        $this.TemplateMetadata = @{}
    }
}
