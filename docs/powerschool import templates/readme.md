# PowerSchool Import Templates

This folder contains reference CSV templates supplied for PowerSchool data imports. Keep these files unchanged so they remain useful for checking official column names, required fields, and example layouts.

These files are documentation artifacts. The synchronization module does not load mappings from this folder.

## Files

### `Students_Data_Import_Template_2022_09.csv`

PowerSchool student import reference. It contains:

- the field-name row
- required and recommended field indicators
- example values
- field descriptions

The instructional rows are not student records and must not be included in a production import file.

### `Student_Contacts_Data_Import_Template_2022_09.csv`

PowerSchool Student Contacts import reference. It documents contact demographics, email addresses, phone numbers, addresses, student relationships, and relationship flags.

For a production file, retain only the field-name header and generated data rows. Remove category, required-field, description, and other instructional rows.

### `Student_Contacts_Example_Data_Import_Template_2022_09.csv`

Example Student Contacts data showing PowerSchool's multi-row contact layout. A contact's demographic values may appear on its first row, while additional rows contain other phone numbers, addresses, or student relationships.

The values are examples only and must not be imported into a live environment.

## Project Integration

Source CSV normalization is configured in [`../../config/templates`](../../config/templates). PowerSchool destination formats are maintained separately in [`../../config/powerschool-maps`](../../config/powerschool-maps).

Current maintained maps include:

- `PowerSchoolStudentApi.psd1`
- `PowerSchoolContactsPowerQuery.psd1`
- `StudentsQuickImport.psd1`

When adding a Data Manager or other import format, create a separate map such as `DM-Student-Email.psd1` or `DM-Contacts.psd1`. Do not add destination column mappings to source templates.

## Updating References

When PowerSchool publishes a newer template:

1. Add the new file without modifying its original contents.
2. Include the release date or version in its filename.
3. Compare its headers and requirements with the maintained map.
4. Update the applicable map and tests when the destination schema changes.
5. Retain older versions when they are still needed for deployed PowerSchool versions.

Do not store real student, parent, credential, or health information in this documentation folder.
