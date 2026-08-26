@{
    TemplateName = 'custom_csv_import_1_contacts'
    Description = 'Parent contacts from the custom student CSV import'
    EntityType = 'PSNormalizedData'
    Delimiter = ','
    CustomParser = 'Import-CustomStudentContactsParser'
    StudentTemplateName = 'custom_csv_import_1'
    KeyField = 'ContactIdentifier'
    PowerSchoolKeyField = 'person_contactNumber'
    PowerSchoolKeyDataType = 'string'
    PowerSchoolApiMapName = 'PowerSchoolContactsPowerQuery'

    ContactIdentifierPrefix = 'JFC-'
    RelationshipNoteColumn = 'Custody Description - Other'
    AffirmativeValues = @('1', 'true', 'yes', 'y')

    # Applied when the source does not explicitly provide the relationship flag.
    RelationshipDefaults = @{
        IsLegalGuardian = $true
        HasCustody = $true
        LivesWith = $true
        AllowSchoolPickup = $true
        IsEmergencyContact = $false
        ReceivesMail = $true
    }

    EmergencyContactDefinition = @{
        NameColumn = 'Emergency Contact Name:'
        PhoneColumn = 'Emergency Contact Phone:'
        RelationshipType = 'Other'
        ContactPriorityOrder = 3
    }

    ParentDefinitions = @(
        @{
            Role = 'Father'
            RelationshipType = 'Father'
            ContactPriorityOrder = 2
            GivenNameColumn = "Father’s Given Name"
            SurnameColumn = "Father’s Surname"
            EmployerColumn = "Father’s Workplace"
            WorkPhoneColumn = "Father’s Work Number"
            CellPhoneColumn = "Father’s Cell Number"
            EmailColumn = "Father’s Email"
            SameAddressColumn = 'Father''s Address same as student'
            StreetColumn = 'Father''s Street Address'
            LineTwoColumn = 'Father''s Street Address Line 2'
            CityColumn = 'Father''s City'
            StateColumns = @('Father''s State / Province', 'Father''s State / Province')
            PostalCodeColumn = 'Father''s Postal / Zip Code'
            LivesWithTerms = @('father', 'dad', 'both parent', 'parents')
        }
        @{
            Role = 'Mother'
            RelationshipType = 'Mother'
            ContactPriorityOrder = 1
            GivenNameColumn = "Mother’s Given Name"
            SurnameColumn = "Mother’s Surname"
            EmployerColumn = "Mother’s Workplace"
            WorkPhoneColumn = "Mother’s Work Number"
            CellPhoneColumn = "Mother’s Cell Number"
            EmailColumn = "Mother’s Email"
            SameAddressColumn = 'Mother''s Address same as student'
            StreetColumn = 'Mother''s Street Address'
            LineTwoColumn = 'Mother''s Street Address Line 2'
            CityColumn = 'Mother''s City'
            StateColumns = @('Mother''s State / Province')
            PostalCodeColumn = 'Mother''s Postal / Zip Code'
            LivesWithTerms = @('mother', 'mom', 'both parent', 'parents')
        }
    )
}