@{
    TemplateName = 'fs_powerschool_nonapi_report_parents'
    Description = 'Final Site Enrollment PowerSchool Non-API Report - Parents/Contacts Export'
    EntityType = 'PSNormalizedData'
    # Custom parser for complex multi-row format (contact rows, phone rows, relationship rows)
    CustomParser = 'Import-FSParentsCustomParser'
    ColumnMappings = @()
}
