@{
    # Template Name
    Name = 'fs_powerschool_nonapi_report'
    
    # Description
    Description = 'Default normalization template for Final Site Enrollment CSV export to PowerSchool API format. Includes mappings for student and parent/contact data.'
    
    # Version
    Version = '1.0.0'
    
    # Supported CSV Types
    SupportedTypes = @('students', 'parents')
    
    # Field Mappings for Students
    Students = @{
        # PowerSchool API Field = CSV Column Name(s) - first match wins
        id = @('studentNumber', 'Student_Number', 'StudentId', 'student_id')
        student_number = @('studentNumber', 'Student_Number', 'StudentId', 'student_id')
        state_province_id = @('FTEID', 'StateId', 'state_id')
        local_id = @('studentNumber', 'Student_Number')
        school_id = @('SchoolID', 'school_id', 'School_ID')
        first_name = @('First_Name', 'FirstName', 'first_name')
        middle_name = @('Middle_Name', 'MiddleName', 'middle_name')
        last_name = @('Last_Name', 'LastName', 'last_name')
        grade_level = @('Grade_Level', 'GradeLevel', 'Grade', 'grade')
        gender = @('Gender', 'gender', 'Sex')
        dob = @('DOB', 'DateOfBirth', 'date_of_birth', 'BirthDate')
        home_phone = @('Home_Phone', 'HomePhone', 'Phone', 'home_phone')
        enroll_status = @('Enroll_Status', 'EnrollStatus', 'Status', 'enroll_status')
        entrydate = @('EntryDate', 'entry_date', 'EnrollmentDate', 'enrollment_date')
        exitdate = @('ExitDate', 'exit_date', 'WithdrawalDate', 'withdrawal_date')
        street = @('Street', 'street', 'Address', 'address1')
        city = @('City', 'city')
        state = @('State', 'state', 'Province', 'province')
        zip = @('Zip', 'zip', 'PostalCode', 'postal_code', 'Postal Code')
        mailing_street = @('Mailing_Street', 'MailingStreet', 'mailing_street', 'mailing_address1')
        mailing_city = @('Mailing_City', 'MailingCity', 'mailing_city')
        mailing_state = @('Mailing_State', 'MailingState', 'mailing_state', 'mailing_province')
        mailing_zip = @('Mailing_Zip', 'MailingZip', 'mailing_zip', 'mailing_postal_code')
        family_ident = @('Family_Ident', 'FamilyIdent', 'family_id')
        
        # Scheduling fields
        grade_next_year = @('Sched_NextYearGrade', 'next_year_grade')
        next_school = @('Next_School', 'next_school')
        scheduled = @('Sched_Scheduled', 'scheduled')
        year_of_graduation = @('Sched_YearOfGraduation', 'graduation_year')
        transfer_comment = @('TransferComment', 'transfer_comment', 'comments')
    }
    
    # Field Mappings for Parents/Contacts
    Parents = @{
        # PowerSchool API Field = CSV Column Name(s)
        id = @('New Contact Identifier', 'ContactId', 'contact_id', 'Contact ID')
        contact_id = @('Contact ID', 'ContactId', 'contact_id')
        prefix = @('Prefix', 'prefix', 'Salutation')
        first_name = @('First Name', 'FirstName', 'first_name')
        middle_name = @('Middle Name', 'MiddleName', 'middle_name')
        last_name = @('Last Name', 'LastName', 'last_name')
        suffix = @('Suffix', 'suffix')
        gender = @('Gender', 'gender', 'Sex')
        employer = @('Employer', 'employer')
        is_active = @('Is Active', 'IsActive', 'active')
        email = @('Email Address', 'Email', 'email', 'contact_email')
        phone_type = @('Phone Type', 'PhoneType', 'phone_type')
        phone_number = @('phoneNumberAsEntered', 'Phone', 'phone_number', 'Phone Number Priority Order')
        is_preferred_phone = @('Is Preferred', 'IsPreferred', 'preferred')
        is_sms = @('Is SMS', 'IsSMS', 'sms_enabled')
        address_type = @('Address Type', 'AddressType', 'address_type')
        street = @('Street', 'street', 'Address', 'address1')
        street_line_two = @('Line Two', 'LineTwo', 'line_two', 'address2')
        unit = @('Unit', 'unit', 'Apt', 'apartment')
        city = @('City', 'city')
        state = @('State', 'state', 'Province', 'province')
        postal_code = @('Postal Code', 'PostalCode', 'postal_code', 'Zip', 'zip')
        
        # Student relationship fields
        student_number = @('studentNumber', 'Student_Number', 'student_id')
        relationship_type = @('Relationship Type', 'RelationshipType', 'relationship')
        relationship_note = @('Relationship Note', 'RelationshipNote', 'relationship_note')
        legal_guardian = @('STUDENTCONTACTDETAILCOREFIELDS.legalGuardian', 'legalGuardian', 'legal_guardian')
        has_custody = @('Contact Has Custody', 'HasCustody', 'custody')
        lives_with = @('Contact Lives With', 'LivesWith', 'lives_with')
        allow_school_pickup = @('Contact Allow School Pickup', 'AllowPickup', 'school_pickup')
        is_emergency_contact = @('Is Emergency Contact', 'IsEmergencyContact', 'emergency_contact')
        receives_mailings = @('Contact Receives Mailings', 'ReceivesMailings', 'receives_mail')
        contact_priority_order = @('Contact Priority Order', 'Priority', 'priority')
    }
    
    
    # Data Type Conversions
    DataTypes = @{
        # Define expected data types for validation
        Students = @{
            school_id = 'int'
            grade_level = 'int'
            enroll_status = 'int'
            scheduled = 'int'
            year_of_graduation = 'int'
        }
        Parents = @{
            is_active = 'bool'
            is_preferred_phone = 'bool'
            is_sms = 'bool'
            legal_guardian = 'bool'
            has_custody = 'bool'
            lives_with = 'bool'
            allow_school_pickup = 'bool'
            is_emergency_contact = 'bool'
            receives_mailings = 'bool'
            contact_priority_order = 'int'
        }
    }
    
    # Value Transformations (optional)
    Transformations = @{
        # Define any value transformations needed
        # Example: Convert boolean strings to actual booleans
        BooleanTrue = @('1', 'true', 'yes', 'y', 'on')
        BooleanFalse = @('0', 'false', 'no', 'n', 'off', '')
    }
    
    # Validation Rules
    Validation = @{
        Students = @{
            RequiredFields = @('student_number', 'first_name', 'last_name', 'school_id')
        }
        Parents = @{
            RequiredFields = @('id')
        }
    }
}
