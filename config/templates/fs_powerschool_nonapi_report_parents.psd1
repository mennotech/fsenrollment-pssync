@{
    TemplateName = 'fs_powerschool_nonapi_report_parents'
    Description = 'Final Site Enrollment PowerSchool Non-API Report - Parents/Contacts Export'
    EntityType = 'PSNormalizedData'
    # Custom parser for complex multi-row format (contact rows, phone rows, relationship rows)
    CustomParser = 'Import-FSParentsCustomParser'
    # Key field for matching records between CSV and PowerSchool
    KeyField = 'ContactIdentifier'
    # PowerSchool API field that corresponds to the key field
    PowerSchoolKeyField = 'person_statecontactid'
    # PowerSchool API key field data type (for proper type conversion during matching)
    PowerSchoolKeyDataType = 'string'
    # Fields to check for changes during comparison
    CheckForChanges = @('FirstName', 'MiddleName', 'LastName')
    # Entity type mappings for hashtable keys (used by custom parser to infer EntityType)
    # Each entity maps to its PowerSchool class and PowerQuery for data retrieval
    EntityTypeMap = @{
        Contact = @{ EntityType = 'PSContact'; PowerQuery = 'com.fsenrollment.dats.person' }
        EmailAddress = @{ EntityType = 'PSEmailAddress'; PowerQuery = 'com.fsenrollment.dats.person.email' }
        PhoneNumber = @{ EntityType = 'PSPhoneNumber'; PowerQuery = 'com.fsenrollment.dats.person.phone' }
        Address = @{ EntityType = 'PSAddress'; PowerQuery = 'com.fsenrollment.dats.person.address' }
        Relationship = @{ EntityType = 'PSStudentContactRelationship'; PowerQuery = 'com.fsenrollment.dats.person.relationship' }
    }
    # Column mappings for each entity type (EntityType is inferred from hashtable key via EntityTypeMap)
    ColumnMappings = @{
        Contact = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string'; PowerSchoolAPIField = 'person_statecontactid' }
            @{ CSVColumn = 'Contact ID'; EntityProperty = 'ContactID'; DataType = 'string'; PowerSchoolAPIField = 'person_id' }
            @{ CSVColumn = 'Prefix'; EntityProperty = 'Prefix'; DataType = 'string' }
            @{ CSVColumn = 'First Name'; EntityProperty = 'FirstName'; DataType = 'string'; PowerSchoolAPIField = 'person_firstname' }
            @{ CSVColumn = 'Middle Name'; EntityProperty = 'MiddleName'; DataType = 'string'; PowerSchoolAPIField = 'person_middlename' }
            @{ CSVColumn = 'Last Name'; EntityProperty = 'LastName'; DataType = 'string'; PowerSchoolAPIField = 'person_lastname' }
            @{ CSVColumn = 'Suffix'; EntityProperty = 'Suffix'; DataType = 'string' }
            @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; DataType = 'string'; PowerSchoolAPIField = 'person_gender_code' }
            @{ CSVColumn = 'Employer'; EntityProperty = 'Employer'; DataType = 'string'; PowerSchoolAPIField = 'person_employer' }
            @{ CSVColumn = 'Is Active'; EntityProperty = 'IsActive'; DataType = 'bool' }
        )
        EmailAddress = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string' }
            @{ CSVColumn = 'Email Address'; EntityProperty = 'EmailAddress'; DataType = 'string' }
            @{ CSVColumn = 'Contact Email Address ID'; EntityProperty = 'EmailAddressID'; DataType = 'string' }
            @{ CSVColumn = 'Is Primary Email Address'; EntityProperty = 'IsPrimary'; DataType = 'bool' }
        )
        PhoneNumber = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string' }
            @{ CSVColumn = 'Phone Number Priority Order'; EntityProperty = 'PriorityOrder'; DataType = 'int' }
            @{ CSVColumn = 'Phone Type'; EntityProperty = 'PhoneType'; DataType = 'string' }
            @{ CSVColumn = 'phoneNumberAsEntered'; EntityProperty = 'PhoneNumber'; DataType = 'string' }
            @{ CSVColumn = 'Is Preferred'; EntityProperty = 'IsPreferred'; DataType = 'bool' }
            @{ CSVColumn = 'Is SMS'; EntityProperty = 'IsSMS'; DataType = 'bool' }
            @{ CSVColumn = 'Contact Phone Number ID'; EntityProperty = 'PhoneNumberID'; DataType = 'string' }
        )
        Address = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string' }
            @{ CSVColumn = 'Address Type'; EntityProperty = 'AddressType'; DataType = 'string' }
            @{ CSVColumn = 'Street'; EntityProperty = 'Street'; DataType = 'string' }
            @{ CSVColumn = 'Line Two'; EntityProperty = 'LineTwo'; DataType = 'string' }
            @{ CSVColumn = 'Unit'; EntityProperty = 'Unit'; DataType = 'string' }
            @{ CSVColumn = 'City'; EntityProperty = 'City'; DataType = 'string' }
            @{ CSVColumn = 'State'; EntityProperty = 'State'; DataType = 'string' }
            @{ CSVColumn = 'Postal Code'; EntityProperty = 'PostalCode'; DataType = 'string' }
            @{ CSVColumn = 'Contact Address ID'; EntityProperty = 'AddressID'; DataType = 'string' }
            @{ CSVColumn = 'Address Priority Order'; EntityProperty = 'PriorityOrder'; DataType = 'int' }
        )
        Relationship = @(
            @{ CSVColumn = 'New Contact Identifier'; EntityProperty = 'ContactIdentifier'; DataType = 'string' }
            @{ CSVColumn = 'studentNumber'; EntityProperty = 'StudentNumber'; DataType = 'string' }
            @{ CSVColumn = '* NOT MAPPED *'; EntityProperty = 'StudentName'; DataType = 'string' }
            @{ CSVColumn = 'Contact Priority Order'; EntityProperty = 'ContactPriorityOrder'; DataType = 'int' }
            @{ CSVColumn = 'Student Contact ID'; EntityProperty = 'StudentContactID'; DataType = 'string' }
            @{ CSVColumn = 'Student Contact Detail ID'; EntityProperty = 'StudentContactDetailID'; DataType = 'string' }
            @{ CSVColumn = 'Relationship Type'; EntityProperty = 'RelationshipType'; DataType = 'string' }
            @{ CSVColumn = 'Relationship Note'; EntityProperty = 'RelationshipNote'; DataType = 'string' }
            @{ CSVColumn = 'STUDENTCONTACTDETAILCOREFIELDS.legalGuardian'; EntityProperty = 'IsLegalGuardian'; DataType = 'bool' }
            @{ CSVColumn = 'Contact Has Custody'; EntityProperty = 'HasCustody'; DataType = 'bool' }
            @{ CSVColumn = 'Contact Lives With'; EntityProperty = 'LivesWith'; DataType = 'bool' }
            @{ CSVColumn = 'Contact Allow School Pickup'; EntityProperty = 'AllowSchoolPickup'; DataType = 'bool' }
            @{ CSVColumn = 'Is Emergency Contact'; EntityProperty = 'IsEmergencyContact'; DataType = 'bool' }
            @{ CSVColumn = 'Contact Receives Mailings'; EntityProperty = 'ReceivesMail'; DataType = 'bool' }
        )
    }
}
