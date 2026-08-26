# PowerSchool Maps

This directory contains one maintained map per PowerSchool import or API format. Maps share a directory but remain separate because each destination has its own core schema.

Current maps:

- `PowerSchoolStudentApi.psd1`: Student API field paths
- `PowerSchoolContactsPowerQuery.psd1`: Contact PowerQuery result fields
- `StudentsQuickImport.psd1`: Quick Import Students columns
- `ContactsDataImportManager.psd1`: Student Contacts Data Import Manager 2022.09 columns

Additional formats should use separate files, such as `DM-Student-Email.psd1`.

## Custom fields

Format maps do not list individual custom fields. Source templates import the actual PowerSchool custom name as the normalized `CustomField` key. Each format map declares only its destination prefix:

```powershell
# Source template
@{ CSVColumn = 'Church Attending'; CustomField = 'church_name' }

# API map
CustomFieldPrefix = 'extension.u_studentsuserfields.'

# Quick Import map
CustomFieldPrefix = 'U_StudentsUserFields.'
```

The resulting destination names are `extension.u_studentsuserfields.church_name` and `U_StudentsUserFields.church_name`.
