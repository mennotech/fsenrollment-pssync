@{
    MapName = 'PowerSchoolStudentApi'
    Description = 'PowerSchool Student API field paths'
    EntityType = 'PSStudent'
    CustomFieldPrefix = 'extension.u_studentsuserfields.'

    Mappings = @(
        @{ EntityProperty = 'StudentNumber'; PowerSchoolAPIField = 'local_id' }
        @{ EntityProperty = 'SchoolID'; PowerSchoolAPIField = 'school_id' }
        @{ EntityProperty = 'EntryDate'; PowerSchoolAPIField = 'entry_date' }
        @{ EntityProperty = 'EntryCode'; PowerSchoolAPIField = 'entry_code' }
        @{ EntityProperty = 'FirstName'; PowerSchoolAPIField = 'name.first_name' }
        @{ EntityProperty = 'MiddleName'; PowerSchoolAPIField = 'name.middle_name' }
        @{ EntityProperty = 'LastName'; PowerSchoolAPIField = 'name.last_name' }
        @{ EntityProperty = 'Gender'; PowerSchoolAPIField = '@demographics.gender' }
        @{ EntityProperty = 'DOB'; PowerSchoolAPIField = '@demographics.birth_date' }
        @{ EntityProperty = 'GradeLevel'; PowerSchoolAPIField = 'grade_level' }
        @{ EntityProperty = 'Street'; PowerSchoolAPIField = '@addresses.physical.street' }
        @{ EntityProperty = 'City'; PowerSchoolAPIField = '@addresses.physical.city' }
        @{ EntityProperty = 'State'; PowerSchoolAPIField = '@addresses.physical.state_province' }
        @{ EntityProperty = 'Zip'; PowerSchoolAPIField = '@addresses.physical.postal_code' }
        @{ EntityProperty = 'MailingStreet'; PowerSchoolAPIField = '@addresses.mailing.street' }
        @{ EntityProperty = 'MailingCity'; PowerSchoolAPIField = '@addresses.mailing.city' }
        @{ EntityProperty = 'MailingState'; PowerSchoolAPIField = '@addresses.mailing.state_province' }
        @{ EntityProperty = 'MailingZip'; PowerSchoolAPIField = '@addresses.mailing.postal_code' }
    )
}