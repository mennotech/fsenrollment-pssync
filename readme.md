# Final Site Enrollment → PowerSchool Sync

Basic PowerShell 7+ tooling to process Final Site Enrollment CSVs and prepare/sync changes to PowerSchool SIS.

What’s here now:
- Module scaffold (`fsenrollmentpssync/`) for future sync cmdlets
- Example CSVs under `data/examples/`
- Utility scripts:
	- `Filter-ParentsByStudentExampleFile.ps1` to filter parent rows by student list
	- `Anonymize-ParentsExampleFile.ps1` to anonymize sample data for sharing/tests

Next steps (high level):
- Parse incoming CSVs, detect changes, and stage an approval file
- Apply approved changes to PowerSchool via API with retries and logging
- Add Pester tests and configuration wiring