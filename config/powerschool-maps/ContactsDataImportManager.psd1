@{
    MapName = 'ContactsDataImportManager'
    Description = 'PowerSchool Student Contacts Data Import Manager 2022.09 format'
    EntityType = 'PSNormalizedData'

    Mappings = @(
        @{ OutputColumn = 'New Contact Identifier'; EntityType = 'Contact'; EntityProperty = 'ContactIdentifier' }
        @{ OutputColumn = 'Contact ID'; EntityType = 'Contact'; EntityProperty = 'ContactID' }
        @{ OutputColumn = 'Prefix'; EntityType = 'Contact'; EntityProperty = 'Prefix'; FirstRowOnly = $true }
        @{ OutputColumn = 'First Name'; EntityType = 'Contact'; EntityProperty = 'FirstName'; FirstRowOnly = $true }
        @{ OutputColumn = 'Middle Name'; EntityType = 'Contact'; EntityProperty = 'MiddleName'; FirstRowOnly = $true }
        @{ OutputColumn = 'Last Name *'; EntityType = 'Contact'; EntityProperty = 'LastName'; FirstRowOnly = $true }
        @{ OutputColumn = 'Suffix'; EntityType = 'Contact'; EntityProperty = 'Suffix'; FirstRowOnly = $true }
        @{ OutputColumn = 'Gender'; EntityType = 'Contact'; EntityProperty = 'Gender'; FirstRowOnly = $true }
        @{ OutputColumn = 'Employer'; EntityType = 'Contact'; EntityProperty = 'Employer'; FirstRowOnly = $true }
        @{ OutputColumn = 'Is Active'; EntityType = 'Contact'; EntityProperty = 'IsActive'; Transform = 'BooleanInt'; FirstRowOnly = $true }
        @{ OutputColumn = 'State Contact ID'; EntityType = 'Contact'; EntityProperty = 'ContactIdentifier'; FirstRowOnly = $true }
        @{ OutputColumn = 'Exclude From State Reporting' }
        @{ OutputColumn = 'PERSONCOREFIELDS.countryOfOrigin' }
        @{ OutputColumn = 'PERSONCOREFIELDS.dob' }
        @{ OutputColumn = 'PERSONCOREFIELDS.educationLevel' }
        @{ OutputColumn = 'PERSONCOREFIELDS.employmentStatus' }
        @{ OutputColumn = 'PERSONCOREFIELDS.govWorkLoc' }
        @{ OutputColumn = 'PERSONCOREFIELDS.isAvailableAtWork' }
        @{ OutputColumn = 'PERSONCOREFIELDS.isDeceased' }
        @{ OutputColumn = 'PERSONCOREFIELDS.isOnActiveDuty' }
        @{ OutputColumn = 'PERSONCOREFIELDS.livesOnBase' }
        @{ OutputColumn = 'PERSONCOREFIELDS.maidenName' }
        @{ OutputColumn = 'PERSONCOREFIELDS.militaryStatus' }
        @{ OutputColumn = 'PERSONCOREFIELDS.needsInterpreterAssist' }
        @{ OutputColumn = 'PERSONCOREFIELDS.occupation' }
        @{ OutputColumn = 'PERSONCOREFIELDS.payGrade' }
        @{ OutputColumn = 'PERSONCOREFIELDS.serviceBranch' }
        @{ OutputColumn = 'PERSONCOREFIELDS.ssn' }
        @{ OutputColumn = 'Email Address'; EntityType = 'EmailAddress'; EntityProperty = 'EmailAddress' }
        @{ OutputColumn = 'Contact Email Address ID'; EntityType = 'EmailAddress'; EntityProperty = 'EmailAddressID' }
        @{ OutputColumn = 'Email Type'; EntityType = 'EmailAddress'; Value = 'Current' }
        @{ OutputColumn = 'Is Primary Email Address'; EntityType = 'EmailAddress'; EntityProperty = 'IsPrimary'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'Extension' }
        @{ OutputColumn = 'Is SMS'; EntityType = 'PhoneNumber'; EntityProperty = 'IsSMS'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'PHONENUMBERCOREFIELDS.isUnlisted' }
        @{ OutputColumn = 'Contact Phone Number ID'; EntityType = 'PhoneNumber'; EntityProperty = 'PhoneNumberID' }
        @{ OutputColumn = 'phoneNumberAsEntered'; EntityType = 'PhoneNumber'; EntityProperty = 'PhoneNumber' }
        @{ OutputColumn = 'Phone Type'; EntityType = 'PhoneNumber'; EntityProperty = 'PhoneType' }
        @{ OutputColumn = 'Phone Number Priority Order'; EntityType = 'PhoneNumber'; EntityProperty = 'PriorityOrder'; Transform = 'PositiveInt' }
        @{ OutputColumn = 'Is Preferred'; EntityType = 'PhoneNumber'; EntityProperty = 'IsPreferred'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'Street'; EntityType = 'Address'; EntityProperty = 'Street' }
        @{ OutputColumn = 'Line Two'; EntityType = 'Address'; EntityProperty = 'LineTwo' }
        @{ OutputColumn = 'Unit'; EntityType = 'Address'; EntityProperty = 'Unit' }
        @{ OutputColumn = 'City'; EntityType = 'Address'; EntityProperty = 'City' }
        @{ OutputColumn = 'State'; EntityType = 'Address'; EntityProperty = 'State' }
        @{ OutputColumn = 'Postal Code'; EntityType = 'Address'; EntityProperty = 'PostalCode' }
        @{ OutputColumn = 'Geocode Latitude' }
        @{ OutputColumn = 'Geocode Longitude' }
        @{ OutputColumn = 'PERSONADDRESSCOREFIELDS.addressVerification' }
        @{ OutputColumn = 'PERSONADDRESSCOREFIELDS.county' }
        @{ OutputColumn = 'PERSONADDRESSCOREFIELDS.isAddressVerified' }
        @{ OutputColumn = 'PERSONADDRESSCOREFIELDS.line3' }
        @{ OutputColumn = 'Contact Address ID'; EntityType = 'Address'; EntityProperty = 'AddressID' }
        @{ OutputColumn = 'Address Type'; EntityType = 'Address'; EntityProperty = 'AddressType' }
        @{ OutputColumn = 'Address Priority Order'; EntityType = 'Address'; EntityProperty = 'PriorityOrder'; Transform = 'PositiveInt' }
        @{ OutputColumn = 'Address Start Date' }
        @{ OutputColumn = 'Address End Date' }
        @{ OutputColumn = '* NOT MAPPED *'; EntityType = 'Relationship'; EntityProperty = 'StudentName' }
        @{ OutputColumn = 'studentNumber'; EntityType = 'Relationship'; EntityProperty = 'StudentNumber' }
        @{ OutputColumn = 'Contact Priority Order'; EntityType = 'Relationship'; EntityProperty = 'ContactPriorityOrder'; Transform = 'PositiveInt' }
        @{ OutputColumn = 'Student Contact ID'; EntityType = 'Relationship'; EntityProperty = 'StudentContactID' }
        @{ OutputColumn = 'Student Contact Detail ID'; EntityType = 'Relationship'; EntityProperty = 'StudentContactDetailID' }
        @{ OutputColumn = 'Relationship Type'; EntityType = 'Relationship'; EntityProperty = 'RelationshipType' }
        @{ OutputColumn = 'Relationship Note'; EntityType = 'Relationship'; EntityProperty = 'RelationshipNote' }
        @{ OutputColumn = 'Relationship Start Date' }
        @{ OutputColumn = 'Relationship End Date' }
        @{ OutputColumn = 'STUDENTCONTACTDETAILCOREFIELDS.legalGuardian'; EntityType = 'Relationship'; EntityProperty = 'IsLegalGuardian'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'Contact Has Custody'; EntityType = 'Relationship'; EntityProperty = 'HasCustody'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'Contact Lives With'; EntityType = 'Relationship'; EntityProperty = 'LivesWith'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'Contact Allow School Pickup'; EntityType = 'Relationship'; EntityProperty = 'AllowSchoolPickup'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'Is Emergency Contact'; EntityType = 'Relationship'; EntityProperty = 'IsEmergencyContact'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'Contact Receives Mailings'; EntityType = 'Relationship'; EntityProperty = 'ReceivesMail'; Transform = 'BooleanInt' }
        @{ OutputColumn = 'STUDENTCONTACTDETAILCOREFIELDS.classroomParticipation' }
        @{ OutputColumn = 'STUDENTCONTACTDETAILCOREFIELDS.isCaregiver' }
        @{ OutputColumn = 'STUDENTCONTACTDETAILCOREFIELDS.isVolunteer' }
    )
}