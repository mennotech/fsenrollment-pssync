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
    PowerSchoolApiMapName = 'PowerSchoolStudentApi'
    # Fields to check for changes during comparison
    CheckForChanges = @('FirstName', 'MiddleName', 'LastName', 'Street', 'City', 'State', 'Zip', 'DOB')
    # Optional: Custom parser function for complex CSV formats
    # If not provided, the default ConvertFrom-CsvRow function is used with ColumnMappings
    CustomParser = $null
    # Column mappings normalize source fields and may specify DateTimeFormat.
    # PowerSchool destination fields are maintained in PowerSchoolStudentApi.psd1.
    ColumnMappings = @(
        @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; DataType = 'string'; PowerSchoolDataType = 'int' }
        @{ CSVColumn = 'SchoolID'; EntityProperty = 'SchoolID'; DataType = 'string' }
        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; DataType = 'string' }
        @{ CSVColumn = 'Middle_Name'; EntityProperty = 'MiddleName'; DataType = 'string' }
        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; DataType = 'string' }
        @{ CSVColumn = 'Grade_Level'; EntityProperty = 'GradeLevel'; DataType = 'int' }
        @{ CSVColumn = 'Home_Phone'; EntityProperty = 'HomePhone'; DataType = 'string' }
        @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; DataType = 'string' }
        @{ CSVColumn = 'DOB'; EntityProperty = 'DOB'; DataType = 'datetime'; DateTimeFormat = 'dd/MM/yyyy' }
        @{ CSVColumn = 'FTEID'; EntityProperty = 'FTEID'; DataType = 'string' }
        @{ CSVColumn = 'Enroll_Status'; EntityProperty = 'EnrollStatus'; DataType = 'int' }
        @{ CSVColumn = 'EntryDate'; EntityProperty = 'EntryDate'; DataType = 'datetime'; DateTimeFormat = 'M/d/yy' }
        @{ CSVColumn = 'ExitDate'; EntityProperty = 'ExitDate'; DataType = 'datetime'; DateTimeFormat = 'M/d/yyyy' }
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
