#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for DateTime format backward compatibility
.DESCRIPTION
    Validates that the datetime format functionality maintains backward compatibility
    and doesn't break existing workflows
#>

BeforeAll {
    Import-Module "$PSScriptRoot\..\FSEnrollment-PSSync.psd1" -Force
}

Describe "DateTime Format Backward Compatibility Tests" {
    Context "Legacy Template Support" {
        It "Should handle templates without DateTimeFormat gracefully" {
            # This test validates that legacy templates still work without DateTimeFormat property
            # by testing against the existing template structure
            
            # Act - Use existing template functionality
            $testCsvContent = @"
Student_Number,First_Name,Last_Name
12345,Jane,Smith
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            $testCsvContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                # Import using existing template - should not fail
                $result = Import-FSCsv -Path $tempFile -TemplateName "fs_powerschool_nonapi_report_students"
                
                # Assert - Should work fine for non-datetime fields
                $result | Should -Not -BeNullOrEmpty
                $result.Students.Count | Should -Be 1
                $result.Students[0].FirstName | Should -Be "Jane"
                $result.Students[0].LastName | Should -Be "Smith"
            }
            finally {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should maintain existing behavior for non-datetime fields" {
            # Arrange
            $testCsvContent = @"
Student_Number,First_Name,Last_Name,Grade_Level,FTEID
12345,Alice,Johnson,9,FTE123
12346,Bob,Williams,10,FTE456
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            $testCsvContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                # Act
                $result = Import-FSCsv -Path $tempFile -TemplateName "fs_powerschool_nonapi_report_students"
                
                # Assert - Non-datetime fields should work exactly as before
                $result.Students.Count | Should -Be 2
                
                $alice = $result.Students | Where-Object { $_.StudentNumber -eq "12345" }
                $alice.FirstName | Should -Be "Alice"
                $alice.LastName | Should -Be "Johnson"
                $alice.GradeLevel | Should -Be 9
                $alice.FTEID | Should -Be "FTE123"
                
                $bob = $result.Students | Where-Object { $_.StudentNumber -eq "12346" }
                $bob.FirstName | Should -Be "Bob"
                $bob.LastName | Should -Be "Williams"
                $bob.GradeLevel | Should -Be 10
                $bob.FTEID | Should -Be "FTE456"
            }
            finally {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should preserve all existing Import-FSCsv functionality" {
            # Arrange
            $testCsvContent = @"
Student_Number,First_Name,Last_Name,Grade_Level,Street,City,State,Zip
98765,Test,Student,11,123 Main St,Anytown,ST,12345
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            $testCsvContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                # Act
                $result = Import-FSCsv -Path $tempFile -TemplateName "fs_powerschool_nonapi_report_students"
                
                # Assert - All existing functionality should work
                $result | Should -Not -BeNullOrEmpty
                $result.Students | Should -Not -BeNullOrEmpty
                $result.Students.Count | Should -Be 1
                
                $student = $result.Students[0]
                $student.StudentNumber | Should -Be "98765"
                $student.FirstName | Should -Be "Test"
                $student.LastName | Should -Be "Student"
                $student.GradeLevel | Should -Be 11
                $student.Street | Should -Be "123 Main St"
                $student.City | Should -Be "Anytown"
                $student.State | Should -Be "ST"
                $student.Zip | Should -Be "12345"
                
                # Verify the result has the expected structure
                $result.PSObject.TypeNames[0] | Should -Be "PSNormalizedData"
                $result.Students | Should -Not -BeNullOrEmpty
            }
            finally {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should handle mixed scenarios with some valid and some invalid dates" {
            # Arrange
            $testCsvContent = @"
Student_Number,First_Name,Last_Name,DOB,EntryDate
12345,Good,Date,31/12/1999,1/15/25
12346,Bad,Date,32/13/1999,1/15/25
12347,Empty,Date,,1/15/25
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            $testCsvContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                # Act
                $warnings = @()
                $result = Import-FSCsv -Path $tempFile -TemplateName "fs_powerschool_nonapi_report_students" -WarningVariable +warnings
                
                # Assert
                $result.Students.Count | Should -Be 3
                
                # Good date should parse correctly
                $goodDate = $result.Students | Where-Object { $_.FirstName -eq "Good" }
                $goodDate.DOB | Should -Be ([datetime]::new(1999, 12, 31))
                $goodDate.EntryDate | Should -Be ([datetime]::new(2025, 1, 15))
                
                # Bad date should remain default and generate warning
                $badDate = $result.Students | Where-Object { $_.FirstName -eq "Bad" }
                $badDate.DOB | Should -Be ([datetime]::MinValue)
                $badDate.EntryDate | Should -Be ([datetime]::new(2025, 1, 15))
                
                # Empty date should remain default and not generate warning
                $emptyDate = $result.Students | Where-Object { $_.FirstName -eq "Empty" }
                $emptyDate.DOB | Should -Be ([datetime]::MinValue)
                $emptyDate.EntryDate | Should -Be ([datetime]::new(2025, 1, 15))
                
                # Should have warning for bad date but not empty date
                $dateWarnings = $warnings | Where-Object { $_ -match "Failed to convert.*to datetime" }
                $dateWarnings.Count | Should -Be 1
                $dateWarnings[0] | Should -Match "32/13/1999"
            }
            finally {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}