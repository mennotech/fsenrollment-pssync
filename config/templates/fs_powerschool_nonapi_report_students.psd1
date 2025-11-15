@{
    TemplateName = 'fs_powerschool_nonapi_report_students'
    Description = 'Final Site Enrollment PowerSchool Non-API Report - Students Export'
    EntityType = 'PSStudent'
    # Key field for matching records between CSV and PowerSchool
    KeyField = 'StudentNumber'
    # PowerSchool API field that corresponds to the key field
    PowerSchoolKeyField = 'local_id'
    # PowerSchool API key field data type (for proper type conversion during matching)
    PowerSchoolKeyDataType = 'int'
    # Fields to check for changes during comparison
    CheckForChanges = @('FirstName', 'MiddleName', 'LastName')
    # Optional: Custom parser function for complex CSV formats
    # If not provided, the default ConvertFrom-CsvRow function is used with ColumnMappings
    CustomParser = $null
    # Column mappings - EntityType is inherited from template-level EntityType
    # PowerSchoolAPIField syntax:
    #   - Standard fields: 'local_id', 'student_number'
    #   - Nested fields: 'name.first_name', 'demographics.gender'
    #   - Extension fields: 'extension.u_students_extension.legal_first_name'
    #   - Expansion fields: '@demographics.birth_date'
    ColumnMappings = @(
        @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; DataType = 'string'; PowerSchoolAPIField = 'local_id'; PowerSchoolDataType = 'int' }
        @{ CSVColumn = 'SchoolID'; EntityProperty = 'SchoolID'; DataType = 'string' }
        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; DataType = 'string'; PowerSchoolAPIField = 'name.first_name' }
        @{ CSVColumn = 'Middle_Name'; EntityProperty = 'MiddleName'; DataType = 'string'; PowerSchoolAPIField = 'name.middle_name' }
        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; DataType = 'string'; PowerSchoolAPIField = 'name.last_name' }
        @{ CSVColumn = 'Grade_Level'; EntityProperty = 'GradeLevel'; DataType = 'int' }
        @{ CSVColumn = 'Home_Phone'; EntityProperty = 'HomePhone'; DataType = 'string' }
        @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; DataType = 'string' }
        @{ CSVColumn = 'DOB'; EntityProperty = 'DOB'; DataType = 'datetime'; PowerSchoolAPIField = '@demographics.birth_date' }
        @{ CSVColumn = 'FTEID'; EntityProperty = 'FTEID'; DataType = 'string' }
        @{ CSVColumn = 'Enroll_Status'; EntityProperty = 'EnrollStatus'; DataType = 'int' }
        @{ CSVColumn = 'EntryDate'; EntityProperty = 'EntryDate'; DataType = 'datetime' }
        @{ CSVColumn = 'ExitDate'; EntityProperty = 'ExitDate'; DataType = 'datetime' }
        @{ CSVColumn = 'Street'; EntityProperty = 'Street'; DataType = 'string' }
        @{ CSVColumn = 'City'; EntityProperty = 'City'; DataType = 'string' }
        @{ CSVColumn = 'State'; EntityProperty = 'State'; DataType = 'string' }
        @{ CSVColumn = 'Zip'; EntityProperty = 'Zip'; DataType = 'string' }
        @{ CSVColumn = 'Mailing_Street'; EntityProperty = 'MailingStreet'; DataType = 'string' }
        @{ CSVColumn = 'Mailing_City'; EntityProperty = 'MailingCity'; DataType = 'string' }
        @{ CSVColumn = 'Mailing_State'; EntityProperty = 'MailingState'; DataType = 'string' }
        @{ CSVColumn = 'Mailing_Zip'; EntityProperty = 'MailingZip'; DataType = 'string' }
        @{ CSVColumn = 'Sched_NextYearGrade'; EntityProperty = 'SchedNextYearGrade'; DataType = 'int' }
        @{ CSVColumn = 'Next_School'; EntityProperty = 'NextSchool'; DataType = 'string' }
        @{ CSVColumn = 'Sched_Scheduled'; EntityProperty = 'SchedScheduled'; DataType = 'int' }
        @{ CSVColumn = 'Sched_YearOfGraduation'; EntityProperty = 'SchedYearOfGraduation'; DataType = 'int' }
        @{ CSVColumn = 'TransferComment'; EntityProperty = 'TransferComment'; DataType = 'string' }
        @{ CSVColumn = 'Family_Ident'; EntityProperty = 'FamilyIdent'; DataType = 'string' }
    )
}
