@{
    MapName = 'StudentsQuickImport'
    Description = 'PowerSchool Quick Import Students format'
    EntityType = 'PSStudent'
    CustomFieldPrefix = 'U_StudentsUserFields.'
    CustomFieldBooleanFormat = 'Integer'

    Mappings = @(
        @{ OutputColumn = 'Student_Number'; EntityProperty = 'StudentNumber' }
        @{ OutputColumn = 'FTEID'; EntityProperty = 'FTEID' }
        @{ OutputColumn = 'SchoolID'; EntityProperty = 'SchoolID' }
        @{ OutputColumn = 'Next_School'; EntityProperty = 'NextSchool' }
        @{ OutputColumn = 'EntryDate'; EntityProperty = 'EntryDate'; DateTimeFormat = 'M/d/yyyy' }
        @{ OutputColumn = 'Home_Room'; EntityProperty = 'HomeRoom' }
        @{ OutputColumn = 'EntryCode'; EntityProperty = 'EntryCode' }
        @{ OutputColumn = 'Email'; EntityProperty = 'Email' }
        @{ OutputColumn = 'First_Name'; EntityProperty = 'FirstName' }
        @{ OutputColumn = 'Middle_Name'; EntityProperty = 'MiddleName' }
        @{ OutputColumn = 'Last_Name'; EntityProperty = 'LastName' }
        @{ OutputColumn = 'PreferedName'; Transform = 'PreferredName' }
        @{ OutputColumn = 'Gender'; EntityProperty = 'Gender' }
        @{ OutputColumn = 'DOB'; EntityProperty = 'DOB'; DateTimeFormat = 'MM/dd/yyyy' }
        @{ OutputColumn = 'Grade_Level'; EntityProperty = 'GradeLevel' }
        @{ OutputColumn = 'Street'; EntityProperty = 'Street' }
        @{ OutputColumn = 'City'; EntityProperty = 'City' }
        @{ OutputColumn = 'State'; EntityProperty = 'State' }
        @{ OutputColumn = 'Zip'; EntityProperty = 'Zip' }
        @{ OutputColumn = 'Mailing_Street'; EntityProperty = 'MailingStreet' }
        @{ OutputColumn = 'Mailing_City'; EntityProperty = 'MailingCity' }
        @{ OutputColumn = 'Mailing_State'; EntityProperty = 'MailingState' }
        @{ OutputColumn = 'Mailing_Zip'; EntityProperty = 'MailingZip' }
        @{ OutputColumn = 'Allergies'; EntityProperty = 'Allergies' }
        @{ OutputColumn = 'Alert_Medical'; EntityProperty = 'MedicalAlert' }
    )
}