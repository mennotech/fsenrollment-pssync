@{
    TemplateName = 'fs_powerschool_nonapi_report_students'
    Description = 'Final Site Enrollment PowerSchool Non-API Report - Students Export'
    EntityType = 'PSStudent'
    # Optional: Custom parser function for complex CSV formats
    # If not provided, the default ConvertFrom-CsvRow function is used with ColumnMappings
    CustomParser = $null
    ColumnMappings = @(
        @{ CSVColumn = 'Student_Number'; EntityProperty = 'StudentNumber'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'SchoolID'; EntityProperty = 'SchoolID'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'First_Name'; EntityProperty = 'FirstName'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Middle_Name'; EntityProperty = 'MiddleName'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Last_Name'; EntityProperty = 'LastName'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Grade_Level'; EntityProperty = 'GradeLevel'; DataType = 'int'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Home_Phone'; EntityProperty = 'HomePhone'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Gender'; EntityProperty = 'Gender'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'DOB'; EntityProperty = 'DOB'; DataType = 'datetime'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'FTEID'; EntityProperty = 'FTEID'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Enroll_Status'; EntityProperty = 'EnrollStatus'; DataType = 'int'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'EntryDate'; EntityProperty = 'EntryDate'; DataType = 'datetime'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'ExitDate'; EntityProperty = 'ExitDate'; DataType = 'datetime'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Street'; EntityProperty = 'Street'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'City'; EntityProperty = 'City'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'State'; EntityProperty = 'State'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Zip'; EntityProperty = 'Zip'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Mailing_Street'; EntityProperty = 'MailingStreet'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Mailing_City'; EntityProperty = 'MailingCity'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Mailing_State'; EntityProperty = 'MailingState'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Mailing_Zip'; EntityProperty = 'MailingZip'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Sched_NextYearGrade'; EntityProperty = 'SchedNextYearGrade'; DataType = 'int'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Next_School'; EntityProperty = 'NextSchool'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Sched_Scheduled'; EntityProperty = 'SchedScheduled'; DataType = 'int'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Sched_YearOfGraduation'; EntityProperty = 'SchedYearOfGraduation'; DataType = 'int'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'TransferComment'; EntityProperty = 'TransferComment'; DataType = 'string'; EntityType = 'PSStudent' }
        @{ CSVColumn = 'Family_Ident'; EntityProperty = 'FamilyIdent'; DataType = 'string'; EntityType = 'PSStudent' }
    )
}
