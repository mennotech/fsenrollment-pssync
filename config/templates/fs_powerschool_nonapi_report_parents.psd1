@{
    TemplateName = 'fs_powerschool_nonapi_report_parents'
    Description = 'Final Site Enrollment PowerSchool Non-API Report - Parents/Contacts Export'
    EntityType = 'PSNormalizedData'
    # Custom parser for complex multi-row format (contact rows, phone rows, relationship rows)
    CustomParser = 'Import-FSParentsCustomParser'
    # Column mappings for each entity type (used by custom parser)
    ColumnMappings = @{
        Contact = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Contact ID'; EntityProperty = 'ContactID'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Prefix'; EntityProperty = 'Prefix'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'First Name'; EntityProperty = 'FirstName'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Middle Name'; EntityProperty = 'MiddleName'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Last Name'; EntityProperty = 'LastName'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Suffix'; EntityProperty = 'Suffix'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Employer'; EntityProperty = 'Employer'; DataType = 'string'; EntityType = 'PSContact' }
            @{ CSVColumn = 'Is Active'; EntityProperty = 'IsActive'; DataType = 'bool'; EntityType = 'PSContact' }
        )
        EmailAddress = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string'; EntityType = 'PSEmailAddress' }
            @{ CSVColumn = 'Email Address'; EntityProperty = 'EmailAddress'; DataType = 'string'; EntityType = 'PSEmailAddress' }
            @{ CSVColumn = 'Contact Email Address ID'; EntityProperty = 'EmailAddressID'; DataType = 'string'; EntityType = 'PSEmailAddress' }
            @{ CSVColumn = 'Is Primary Email Address'; EntityProperty = 'IsPrimary'; DataType = 'bool'; EntityType = 'PSEmailAddress' }
        )
        PhoneNumber = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string'; EntityType = 'PSPhoneNumber' }
            @{ CSVColumn = 'Phone Number Priority Order'; EntityProperty = 'PriorityOrder'; DataType = 'int'; EntityType = 'PSPhoneNumber' }
            @{ CSVColumn = 'Phone Type'; EntityProperty = 'PhoneType'; DataType = 'string'; EntityType = 'PSPhoneNumber' }
            @{ CSVColumn = 'phoneNumberAsEntered'; EntityProperty = 'PhoneNumber'; DataType = 'string'; EntityType = 'PSPhoneNumber' }
            @{ CSVColumn = 'Is Preferred'; EntityProperty = 'IsPreferred'; DataType = 'bool'; EntityType = 'PSPhoneNumber' }
            @{ CSVColumn = 'Is SMS'; EntityProperty = 'IsSMS'; DataType = 'bool'; EntityType = 'PSPhoneNumber' }
            @{ CSVColumn = 'Contact Phone Number ID'; EntityProperty = 'PhoneNumberID'; DataType = 'string'; EntityType = 'PSPhoneNumber' }
        )
        Address = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'Address Type'; EntityProperty = 'AddressType'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'Street'; EntityProperty = 'Street'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'Line Two'; EntityProperty = 'LineTwo'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'Unit'; EntityProperty = 'Unit'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'City'; EntityProperty = 'City'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'State'; EntityProperty = 'State'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'Postal Code'; EntityProperty = 'PostalCode'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'Contact Address ID'; EntityProperty = 'AddressID'; DataType = 'string'; EntityType = 'PSAddress' }
            @{ CSVColumn = 'Address Priority Order'; EntityProperty = 'PriorityOrder'; DataType = 'int'; EntityType = 'PSAddress' }
        )
        Relationship = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'studentNumber'; EntityProperty = 'StudentNumber'; DataType = 'string'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = '* NOT MAPPED *'; EntityProperty = 'StudentName'; DataType = 'string'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Contact Priority Order'; EntityProperty = 'ContactPriorityOrder'; DataType = 'int'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Student Contact ID'; EntityProperty = 'StudentContactID'; DataType = 'string'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Student Contact Detail ID'; EntityProperty = 'StudentContactDetailID'; DataType = 'string'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Relationship Type'; EntityProperty = 'RelationshipType'; DataType = 'string'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Relationship Note'; EntityProperty = 'RelationshipNote'; DataType = 'string'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'STUDENTCONTACTDETAILCOREFIELDS.legalGuardian'; EntityProperty = 'IsLegalGuardian'; DataType = 'bool'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Contact Has Custody'; EntityProperty = 'HasCustody'; DataType = 'bool'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Contact Lives With'; EntityProperty = 'LivesWith'; DataType = 'bool'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Contact Allow School Pickup'; EntityProperty = 'AllowSchoolPickup'; DataType = 'bool'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Is Emergency Contact'; EntityProperty = 'IsEmergencyContact'; DataType = 'bool'; EntityType = 'PSStudentContactRelationship' }
            @{ CSVColumn = 'Contact Receives Mailings'; EntityProperty = 'ReceivesMail'; DataType = 'bool'; EntityType = 'PSStudentContactRelationship' }
        )
    }
}
