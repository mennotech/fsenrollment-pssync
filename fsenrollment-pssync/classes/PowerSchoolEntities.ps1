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
    [bool]$ExcludeFromExport

    PSContact() {}
}

# Email address entity
class PSEmailAddress {
    [string]$ContactIdentifier
    [string]$EmailAddress
    [string]$EmailAddressID
    [bool]$IsPrimary
    [bool]$ExcludeFromExport

    PSEmailAddress() {}
    
    # Factory method to create from PSCustomObject (e.g., from JSON deserialization)
    static [PSEmailAddress] FromObject([object]$obj) {
        $email = [PSEmailAddress]::new()
        
        if ($obj.PSObject.Properties['ContactIdentifier']) {
            $email.ContactIdentifier = $obj.ContactIdentifier
        }
        if ($obj.PSObject.Properties['EmailAddress']) {
            $email.EmailAddress = $obj.EmailAddress
        }
        if ($obj.PSObject.Properties['EmailAddressID']) {
            $email.EmailAddressID = $obj.EmailAddressID
        }
        if ($obj.PSObject.Properties['IsPrimary']) {
            $email.IsPrimary = [bool]$obj.IsPrimary
        }
        if ($obj.PSObject.Properties['ExcludeFromExport']) {
            $email.ExcludeFromExport = [bool]$obj.ExcludeFromExport
        }
        
        return $email
    }
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
    [bool]$ExcludeFromExport

    PSPhoneNumber() {}
    
    # Factory method to create from PSCustomObject (e.g., from JSON deserialization)
    static [PSPhoneNumber] FromObject([object]$obj) {
        $phone = [PSPhoneNumber]::new()
        
        if ($obj.PSObject.Properties['ContactIdentifier']) {
            $phone.ContactIdentifier = $obj.ContactIdentifier
        }
        if ($obj.PSObject.Properties['PriorityOrder']) {
            $phone.PriorityOrder = [int]$obj.PriorityOrder
        }
        if ($obj.PSObject.Properties['PhoneType']) {
            $phone.PhoneType = $obj.PhoneType
        }
        if ($obj.PSObject.Properties['PhoneNumber']) {
            $phone.PhoneNumber = $obj.PhoneNumber
        }
        if ($obj.PSObject.Properties['IsPreferred']) {
            $phone.IsPreferred = [bool]$obj.IsPreferred
        }
        if ($obj.PSObject.Properties['IsSMS']) {
            $phone.IsSMS = [bool]$obj.IsSMS
        }
        if ($obj.PSObject.Properties['PhoneNumberID']) {
            $phone.PhoneNumberID = $obj.PhoneNumberID
        }
        if ($obj.PSObject.Properties['ExcludeFromExport']) {
            $phone.ExcludeFromExport = [bool]$obj.ExcludeFromExport
        }
        
        return $phone
    }
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
    [bool]$ExcludeFromExport

    PSAddress() {}
    
    # Factory method to create from PSCustomObject (e.g., from JSON deserialization)
    static [PSAddress] FromObject([object]$obj) {
        $address = [PSAddress]::new()
        
        if ($obj.PSObject.Properties['ContactIdentifier']) {
            $address.ContactIdentifier = $obj.ContactIdentifier
        }
        if ($obj.PSObject.Properties['AddressType']) {
            $address.AddressType = $obj.AddressType
        }
        if ($obj.PSObject.Properties['Street']) {
            $address.Street = $obj.Street
        }
        if ($obj.PSObject.Properties['LineTwo']) {
            $address.LineTwo = $obj.LineTwo
        }
        if ($obj.PSObject.Properties['Unit']) {
            $address.Unit = $obj.Unit
        }
        if ($obj.PSObject.Properties['City']) {
            $address.City = $obj.City
        }
        if ($obj.PSObject.Properties['State']) {
            $address.State = $obj.State
        }
        if ($obj.PSObject.Properties['PostalCode']) {
            $address.PostalCode = $obj.PostalCode
        }
        if ($obj.PSObject.Properties['AddressID']) {
            $address.AddressID = $obj.AddressID
        }
        if ($obj.PSObject.Properties['PriorityOrder']) {
            $address.PriorityOrder = [int]$obj.PriorityOrder
        }
        if ($obj.PSObject.Properties['ExcludeFromExport']) {
            $address.ExcludeFromExport = [bool]$obj.ExcludeFromExport
        }
        
        return $address
    }
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
    [bool]$ExcludeFromExport

    PSStudentContactRelationship() {}
    
    # Factory method to create from PSCustomObject (e.g., from JSON deserialization)
    static [PSStudentContactRelationship] FromObject([object]$obj) {
        $relationship = [PSStudentContactRelationship]::new()
        
        if ($obj.PSObject.Properties['ContactIdentifier']) {
            $relationship.ContactIdentifier = $obj.ContactIdentifier
        }
        if ($obj.PSObject.Properties['StudentNumber']) {
            $relationship.StudentNumber = $obj.StudentNumber
        }
        if ($obj.PSObject.Properties['StudentName']) {
            $relationship.StudentName = $obj.StudentName
        }
        if ($obj.PSObject.Properties['ContactPriorityOrder']) {
            $relationship.ContactPriorityOrder = [int]$obj.ContactPriorityOrder
        }
        if ($obj.PSObject.Properties['StudentContactID']) {
            $relationship.StudentContactID = $obj.StudentContactID
        }
        if ($obj.PSObject.Properties['StudentContactDetailID']) {
            $relationship.StudentContactDetailID = $obj.StudentContactDetailID
        }
        if ($obj.PSObject.Properties['RelationshipType']) {
            $relationship.RelationshipType = $obj.RelationshipType
        }
        if ($obj.PSObject.Properties['RelationshipNote']) {
            $relationship.RelationshipNote = $obj.RelationshipNote
        }
        if ($obj.PSObject.Properties['IsLegalGuardian']) {
            $relationship.IsLegalGuardian = [bool]$obj.IsLegalGuardian
        }
        if ($obj.PSObject.Properties['HasCustody']) {
            $relationship.HasCustody = [bool]$obj.HasCustody
        }
        if ($obj.PSObject.Properties['LivesWith']) {
            $relationship.LivesWith = [bool]$obj.LivesWith
        }
        if ($obj.PSObject.Properties['AllowSchoolPickup']) {
            $relationship.AllowSchoolPickup = [bool]$obj.AllowSchoolPickup
        }
        if ($obj.PSObject.Properties['IsEmergencyContact']) {
            $relationship.IsEmergencyContact = [bool]$obj.IsEmergencyContact
        }
        if ($obj.PSObject.Properties['ReceivesMail']) {
            $relationship.ReceivesMail = [bool]$obj.ReceivesMail
        }
        if ($obj.PSObject.Properties['ExcludeFromExport']) {
            $relationship.ExcludeFromExport = [bool]$obj.ExcludeFromExport
        }
        
        return $relationship
    }
}

# Container class for all normalized data from a CSV import
class PSNormalizedData {
    [System.Collections.Generic.List[PSStudent]]$Students
    [System.Collections.Generic.List[PSContact]]$Contacts
    [System.Collections.Generic.List[PSEmailAddress]]$EmailAddresses
    [System.Collections.Generic.List[PSPhoneNumber]]$PhoneNumbers
    [System.Collections.Generic.List[PSAddress]]$Addresses
    [System.Collections.Generic.List[PSStudentContactRelationship]]$Relationships
    [PSCustomObject]$TemplateMetadata

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
