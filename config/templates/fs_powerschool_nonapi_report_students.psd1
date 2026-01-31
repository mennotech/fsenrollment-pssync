@{
    TemplateName = 'fs_powerschool_nonapi_report_students'
    Description = 'Final Site Enrollment PowerSchool Non-API Report - Students Export'
    EntityType = 'PSStudent'
    # DateTime format used in CSV files (adjust based on FinalSite location settings)
    # This is the default format. Individual columns can override with their own DateTimeFormat property.
    # Common formats: 'MM/dd/yyyy' (US), 'dd/MM/yyyy' (International), 'yyyy-MM-dd' (ISO)
    DateTimeFormat = 'dd/MM/yyyy'
    # Key field for matching records between CSV and PowerSchool
    KeyField = 'StudentNumber'
    # PowerSchool API field that corresponds to the key field
    PowerSchoolKeyField = 'local_id'
    # PowerSchool API key field data type (for proper type conversion during matching)
    PowerSchoolKeyDataType = 'int'
    # Fields to check for changes during comparison
    CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'Street', 'City', 'State', 'Zip', 'DOB')
    # Optional: Custom parser function for complex CSV formats
    # If not provided, the default ConvertFrom-CsvRow function is used with ColumnMappings
    CustomParser = $null
    # Column mappings - EntityType is inherited from template-level EntityType
    # Each mapping can optionally specify DateTimeFormat for datetime fields
    # PowerSchoolAPIField syntax:
    #   - Standard fields: 'local_id', 'student_number'
    #   - Nested fields: 'name.first_name', 'demographics.gender'
    #   - Extension fields: 'extension.u_students_extension.legal_first_name'
    #   - Expansion fields: '@demographics.birth_date'
    ColumnMappings = @(
        @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; DataType = 'string'; PowerSchoolAPIField = 'local_id'; PowerSchoolDataType = 'int' }
        @{ CSVColumn = 'SchoolID'; EntityProperty = 'SchoolID'; DataType = 'string' }
        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; DataType = 'string'; PowerSchoolAPIField = 'name.first_name' }
        # Alternative example: Use this mapping instead if you want to map FirstName to an extension field
        #@{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; DataType = 'string'; PowerSchoolAPIField = 'extension.u_students_extension.legal_first_name' }
        @{ CSVColumn = 'Middle_Name'; EntityProperty = 'MiddleName'; DataType = 'string'; PowerSchoolAPIField = 'name.middle_name' }
        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; DataType = 'string'; PowerSchoolAPIField = 'name.last_name' }
        @{ CSVColumn = 'Grade_Level'; EntityProperty = 'GradeLevel'; DataType = 'int' }
        @{ CSVColumn = 'Home_Phone'; EntityProperty = 'HomePhone'; DataType = 'string' }
        @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; DataType = 'string' }
        @{ CSVColumn = 'DOB'; EntityProperty = 'DOB'; DataType = 'datetime'; DateTimeFormat = 'dd/MM/yyyy'; PowerSchoolAPIField = '@demographics.birth_date' }
        @{ CSVColumn = 'FTEID'; EntityProperty = 'FTEID'; DataType = 'string' }
        @{ CSVColumn = 'Enroll_Status'; EntityProperty = 'EnrollStatus'; DataType = 'int' }
        @{ CSVColumn = 'EntryDate'; EntityProperty = 'EntryDate'; DataType = 'datetime'; DateTimeFormat = 'M/d/yy' }
        @{ CSVColumn = 'ExitDate'; EntityProperty = 'ExitDate'; DataType = 'datetime'; DateTimeFormat = 'M/d/yyyy' }
        @{ CSVColumn = 'Street'; EntityProperty = 'Street'; DataType = 'string'; PowerSchoolAPIField = '@addresses.physical.street' }
        @{ CSVColumn = 'City'; EntityProperty = 'City'; DataType = 'string'; PowerSchoolAPIField = '@addresses.physical.city' }
        @{ CSVColumn = 'State'; EntityProperty = 'State'; DataType = 'string'; PowerSchoolAPIField = '@addresses.physical.state_province' }
        @{ CSVColumn = 'Zip'; EntityProperty = 'Zip'; DataType = 'string'; PowerSchoolAPIField = '@addresses.physical.postal_code' }
        @{ CSVColumn = 'Mailing_Street'; EntityProperty = 'MailingStreet'; DataType = 'string'; PowerSchoolAPIField = '@addresses.mailing.street' }
        @{ CSVColumn = 'Mailing_City'; EntityProperty = 'MailingCity'; DataType = 'string'; PowerSchoolAPIField = '@addresses.mailing.city' }
        @{ CSVColumn = 'Mailing_State'; EntityProperty = 'MailingState'; DataType = 'string'; PowerSchoolAPIField = '@addresses.mailing.state_province' }
        @{ CSVColumn = 'Mailing_Zip'; EntityProperty = 'MailingZip'; DataType = 'string'; PowerSchoolAPIField = '@addresses.mailing.postal_code' }
        @{ CSVColumn = 'Sched_NextYearGrade'; EntityProperty = 'SchedNextYearGrade'; DataType = 'int' }
        @{ CSVColumn = 'Next_School'; EntityProperty = 'NextSchool'; DataType = 'string' }
        @{ CSVColumn = 'Sched_Scheduled'; EntityProperty = 'SchedScheduled'; DataType = 'int' }
        @{ CSVColumn = 'Sched_YearOfGraduation'; EntityProperty = 'SchedYearOfGraduation'; DataType = 'int' }
        @{ CSVColumn = 'TransferComment'; EntityProperty = 'TransferComment'; DataType = 'string' }
        @{ CSVColumn = 'Family_Ident'; EntityProperty = 'FamilyIdent'; DataType = 'string' }
    )
}
