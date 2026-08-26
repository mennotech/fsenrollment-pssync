@{
    MapName = 'PowerSchoolContactsPowerQuery'
    Description = 'PowerSchool contact PowerQuery result field mappings'

    Mappings = @(
        @{ EntityType = 'Contact'; EntityProperty = 'ContactIdentifier'; PowerSchoolAPIField = 'person_contactNumber' }
        @{ EntityType = 'Contact'; EntityProperty = 'ContactID'; PowerSchoolAPIField = 'person_id' }
        @{ EntityType = 'Contact'; EntityProperty = 'FirstName'; PowerSchoolAPIField = 'person_firstName' }
        @{ EntityType = 'Contact'; EntityProperty = 'MiddleName'; PowerSchoolAPIField = 'person_middleName' }
        @{ EntityType = 'Contact'; EntityProperty = 'LastName'; PowerSchoolAPIField = 'person_lastName' }
        @{ EntityType = 'Contact'; EntityProperty = 'Gender'; PowerSchoolAPIField = 'person_gender' }
        @{ EntityType = 'Contact'; EntityProperty = 'Employer'; PowerSchoolAPIField = 'person_employer' }
        @{ EntityType = 'Contact'; EntityProperty = 'IsActive'; PowerSchoolAPIField = 'person_active' }

        @{ EntityType = 'EmailAddress'; EntityProperty = 'EmailAddress'; PowerSchoolAPIField = 'emailaddress_emailAddress' }
        @{ EntityType = 'EmailAddress'; EntityProperty = 'EmailAddressID'; PowerSchoolAPIField = 'emailaddress_id' }
        @{ EntityType = 'EmailAddress'; EntityProperty = 'ContactEmailID'; PowerSchoolAPIField = 'emailaddress_contactEmailId' }
        @{ EntityType = 'EmailAddress'; EntityProperty = 'IsPrimary'; PowerSchoolAPIField = 'emailaddress_isPrimary' }

        @{ EntityType = 'PhoneNumber'; EntityProperty = 'PriorityOrder'; PowerSchoolAPIField = 'phonenumber_order' }
        @{ EntityType = 'PhoneNumber'; EntityProperty = 'PhoneType'; PowerSchoolAPIField = 'phonenumber_type' }
        @{ EntityType = 'PhoneNumber'; EntityProperty = 'PhoneNumber'; PowerSchoolAPIField = 'phonenumber_phoneNumber' }
        @{ EntityType = 'PhoneNumber'; EntityProperty = 'IsPreferred'; PowerSchoolAPIField = 'phonenumber_isPreferred' }
        @{ EntityType = 'PhoneNumber'; EntityProperty = 'IsSMS'; PowerSchoolAPIField = 'phonenumber_isSMS' }
        @{ EntityType = 'PhoneNumber'; EntityProperty = 'PhoneNumberID'; PowerSchoolAPIField = 'phonenumber_id' }
        @{ EntityType = 'PhoneNumber'; EntityProperty = 'ContactPhoneID'; PowerSchoolAPIField = 'phonenumber_contactPhoneId' }

        @{ EntityType = 'Address'; EntityProperty = 'AddressType'; PowerSchoolAPIField = 'address_type' }
        @{ EntityType = 'Address'; EntityProperty = 'Street'; PowerSchoolAPIField = 'address_street' }
        @{ EntityType = 'Address'; EntityProperty = 'LineTwo'; PowerSchoolAPIField = 'address_lineTwo' }
        @{ EntityType = 'Address'; EntityProperty = 'Unit'; PowerSchoolAPIField = 'address_unit' }
        @{ EntityType = 'Address'; EntityProperty = 'City'; PowerSchoolAPIField = 'address_city' }
        @{ EntityType = 'Address'; EntityProperty = 'State'; PowerSchoolAPIField = 'address_state' }
        @{ EntityType = 'Address'; EntityProperty = 'PostalCode'; PowerSchoolAPIField = 'address_postalCode' }
        @{ EntityType = 'Address'; EntityProperty = 'AddressID'; PowerSchoolAPIField = 'address_id' }
        @{ EntityType = 'Address'; EntityProperty = 'ContactAddressID'; PowerSchoolAPIField = 'address_contactAddressId' }
        @{ EntityType = 'Address'; EntityProperty = 'PriorityOrder'; PowerSchoolAPIField = 'address_order' }

        @{ EntityType = 'Relationship'; EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'student_student_number' }
        @{ EntityType = 'Relationship'; EntityProperty = 'ContactPriorityOrder'; PowerSchoolAPIField = 'relationship_priority_order' }
        @{ EntityType = 'Relationship'; EntityProperty = 'RelationshipType'; PowerSchoolAPIField = 'relationship_relationship_code' }
        @{ EntityType = 'Relationship'; EntityProperty = 'RelationshipNote'; PowerSchoolAPIField = 'relationship_relationship_note' }
        @{ EntityType = 'Relationship'; EntityProperty = 'HasCustody'; PowerSchoolAPIField = 'relationship_iscustodial' }
        @{ EntityType = 'Relationship'; EntityProperty = 'LivesWith'; PowerSchoolAPIField = 'relationship_livesWith' }
        @{ EntityType = 'Relationship'; EntityProperty = 'AllowSchoolPickup'; PowerSchoolAPIField = 'relationship_schoolPickup' }
        @{ EntityType = 'Relationship'; EntityProperty = 'IsEmergencyContact'; PowerSchoolAPIField = 'relationship_isEmergency' }
        @{ EntityType = 'Relationship'; EntityProperty = 'ReceivesMail'; PowerSchoolAPIField = 'relationship_receivesMail' }
    )
}
