@{
    TemplateName = 'custom_csv_import_1'
    Description = 'Example custom student CSV import'
    EntityType = 'PSStudent'
    Delimiter = ','
    DateTimeFormat = 'dd-MMM-yy'
    KeyField = 'StudentNumber'
    PowerSchoolKeyField = 'local_id'
    PowerSchoolKeyDataType = 'int'
    PowerSchoolApiMapName = 'PowerSchoolStudentApi'
    CheckForChanges = @(
        'FirstName', 'MiddleName', 'LastName', 'Gender', 'DOB', 'GradeLevel',
        'Street', 'City', 'State', 'Zip', 'MailingStreet', 'MailingCity', 'MailingState', 'MailingZip',
        'CustomFields.legal_givenname', 'CustomFields.legal_surname', 'CustomFields.legal_middlenames',
        'CustomFields.church_name', 'CustomFields.church_denomination', 'CustomFields.phin_9digit',
        'CustomFields.phin_6digit', 'CustomFields.HAS_FOOD_ALLERGY'
    )
    CustomParser = $null

    ColumnMappings = @(
        @{
            EntityProperty = 'StudentNumber'
            DataType = 'string'
            PowerSchoolDataType = 'int'
            Transform = 'ComposeString'
            Parts = @(
                @{ Column = 'Applying For Grade'; Operations = @(@{ Name = 'GraduationYear'; SchoolYearStart = 2026; FinalGrade = 12 }, @{ Name = 'Right'; Count = 2 }) }
                @{ Sequence = @{ Width = 2 } }
            )
        }
        @{ EntityProperty = 'FTEID'; DataType = 'string'; Transform = 'Constant'; Value = '551' }
        @{ EntityProperty = 'SchoolID'; DataType = 'string'; Transform = 'Constant'; Value = '961453' }
        @{ EntityProperty = 'NextSchool'; DataType = 'string'; Transform = 'Constant'; Value = '961453' }
        @{ EntityProperty = 'EntryDate'; DataType = 'datetime'; DateTimeFormat = 'M/d/yyyy'; Transform = 'Constant'; Value = '8/24/2026' }
        @{ CSVColumn = 'Applying For Grade'; EntityProperty = 'HomeRoom'; DataType = 'string'; Transform = 'Lookup'; Map = @{ '1' = 'PP Grade 1/2'; '2' = 'PP Grade 1/2'; '3' = 'PP Grade 3/4'; '4' = 'PP Grade 3/4'; '5' = 'PP Middle Years'; '6' = 'PP Middle Years'; '7' = 'PP Middle Years'; '8' = 'PP Middle Years' } }
        @{ EntityProperty = 'EntryCode'; DataType = 'string'; Transform = 'Constant'; Value = '100' }
        @{
            EntityProperty = 'Email'
            DataType = 'string'
            Transform = 'ComposeString'
            Parts = @(
                @{ Columns = @('Student''s Preferred Name (if different from legal first name)', 'First Name'); Operations = @('Trim', 'Alphanumeric', 'Lower') }
                @{ Column = 'Last Name'; Operations = @(@{ Name = 'First'; Count = 1 }, 'Alphanumeric', 'Lower') }
                @{ Column = 'Applying For Grade'; Operations = @(@{ Name = 'GraduationYear'; SchoolYearStart = 2026; FinalGrade = 12 }, @{ Name = 'Right'; Count = 2 }) }
                @{ Literal = '@sc.school' }
            )
        }
        @{ EntityProperty = 'FirstName'; DataType = 'string'; Transform = 'CoalesceColumns'; Columns = @('Student''s Preferred Name (if different from legal first name)', 'First Name') }
        @{ CSVColumn = 'Last Name'; EntityProperty = 'LastName'; DataType = 'string' }
        @{ CSVColumn = 'First Name'; CustomField = 'legal_givenname'; DataType = 'string' }
        @{ CSVColumn = 'Last Name'; CustomField = 'legal_surname'; DataType = 'string' }
        @{ CSVColumn = 'Middle Name(s)'; CustomField = 'legal_middlenames'; DataType = 'string' }
        @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; DataType = 'string'; Transform = 'GenderCode' }
        @{ CSVColumn = 'Birth Date'; EntityProperty = 'DOB'; DataType = 'datetime'; DateTimeFormat = 'MMM d, yyyy' }
        @{ CSVColumn = 'Applying For Grade'; EntityProperty = 'GradeLevel'; DataType = 'int' }

        @{ EntityProperty = 'Street'; DataType = 'string'; Transform = 'JoinColumns'; Columns = @('Street Address', 'Street Address Line 2'); Separator = ' ' }
        @{ CSVColumn = 'City'; EntityProperty = 'City'; DataType = 'string' }
        @{ CSVColumn = 'State / Province'; EntityProperty = 'State'; DataType = 'string'; Transform = 'NormalizeStateProv'; Countries = @('CA'); Format = 'Abbreviation'; OnInvalid = 'Keep' }
        @{ CSVColumn = 'Postal / Zip Code'; EntityProperty = 'Zip'; DataType = 'string'; Transform = 'NormalizePostalCode'; Format = 'Spaced'; OnInvalid = 'Keep' }

        @{ EntityProperty = 'MailingStreet'; DataType = 'string'; Transform = 'CoalesceColumnGroups'; ColumnGroups = @(@('Mailing Street Address', 'Mailing Street Address Line 2'), @('Street Address', 'Street Address Line 2')); Separator = ' ' }
        @{ EntityProperty = 'MailingCity'; DataType = 'string'; Transform = 'CoalesceColumns'; Columns = @('Mailing City', 'City') }
        @{ EntityProperty = 'MailingState'; DataType = 'string'; Transform = 'NormalizeStateProv'; Columns = @('Mailing State / Province', 'State / Province'); Countries = @('CA'); Format = 'Abbreviation'; OnInvalid = 'Keep' }
        @{ EntityProperty = 'MailingZip'; DataType = 'string'; Transform = 'NormalizePostalCode'; Columns = @('Mailing Postal / Zip Code', 'Postal / Zip Code'); Format = 'Spaced'; OnInvalid = 'Keep' }

        @{ CSVColumn = 'Church Attending'; CustomField = 'church_name'; DataType = 'string' }
        @{ CSVColumn = 'Denomination'; CustomField = 'church_denomination'; DataType = 'string' }
        @{ CSVColumn = 'MB Health # - 9 Digit'; CustomField = 'phin_9digit'; DataType = 'string' }
        @{ CSVColumn = 'MB Health # - 6 Digit'; CustomField = 'phin_6digit'; DataType = 'string' }
        @{ CSVColumn = 'Allergies:'; EntityProperty = 'Allergies'; DataType = 'string'; Transform = 'NormalizeEmpty'; EmptyValues = @('None', 'NA', 'None known', 'No know Allergies') }
        @{ CSVColumn = 'Allergies:'; CustomField = 'HAS_FOOD_ALLERGY'; DataType = 'bool'; Transform = 'NonEmptyFlag'; EmptyValues = @('None', 'NA', 'None known', 'No know Allergies') }
        @{ CSVColumn = 'Medical Restrictions & Medications:'; EntityProperty = 'MedicalAlert'; DataType = 'string'; Transform = 'NormalizeEmpty'; EmptyValues = @('None',"NA") }
    )
}