#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for DateTime format functionality in template configurations
.DESCRIPTION
    Validates that templates correctly specify and use DateTime formats for parsing CSV data
#>

BeforeAll {
    Import-Module "$PSScriptRoot\..\FSEnrollment-PSSync.psd1" -Force
}

Describe "Template DateTime Format Configuration Tests" {
    Context "Template DateTime Format Loading" {
        It "Should load student template with DateTimeFormat configuration" {
            # Arrange & Act
            $templatePath = "$PSScriptRoot\..\..\config\templates\fs_powerschool_nonapi_report_students.psd1"
            $template = Import-PowerShellDataFile -Path $templatePath
            
            # Assert
            $template | Should -Not -BeNullOrEmpty
            $template.DateTimeFormat | Should -Not -BeNullOrEmpty
            $template.DateTimeFormat | Should -BeOfType [string]
            $template.DateTimeFormat | Should -Match '^(MM/dd/yyyy|dd/MM/yyyy|yyyy-MM-dd)$'
        }
        
        It "Should load parent template with DateTimeFormat configuration" {
            # Arrange & Act
            $templatePath = "$PSScriptRoot\..\..\config\templates\fs_powerschool_nonapi_report_parents.psd1"
            $template = Import-PowerShellDataFile -Path $templatePath
            
            # Assert
            $template | Should -Not -BeNullOrEmpty
            $template.DateTimeFormat | Should -Not -BeNullOrEmpty
            $template.DateTimeFormat | Should -BeOfType [string]
            $template.DateTimeFormat | Should -Match '^(MM/dd/yyyy|dd/MM/yyyy|yyyy-MM-dd)$'
        }
        
        It "Should have DateTimeFormat in template before ColumnMappings" {
            # Arrange & Act
            $templatePath = "$PSScriptRoot\..\..\config\templates\fs_powerschool_nonapi_report_students.psd1"
            $templateContent = Get-Content -Path $templatePath -Raw
            
            # Assert - DateTimeFormat should appear before ColumnMappings in file
            $dateTimeFormatIndex = $templateContent.IndexOf('DateTimeFormat')
            $columnMappingsIndex = $templateContent.IndexOf('ColumnMappings')
            
            $dateTimeFormatIndex | Should -BeGreaterThan -1
            $columnMappingsIndex | Should -BeGreaterThan -1
            $dateTimeFormatIndex | Should -BeLessThan $columnMappingsIndex
        }
    }
    
    Context "DateTime Format Validation Through Import-FSCsv" {
        It "Should show helpful warnings when datetime parsing fails" {
            # Arrange - Create test CSV with MM/dd/yyyy format but template expects dd/MM/yyyy for DOB
            $testCsvContent = @"
Student_Number,First_Name,Last_Name,DOB
12345,John,Doe,12/31/1999
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            $testCsvContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                # Act - Import with US format template (should generate warnings)
                $warnings = @()
                $result = Import-FSCsv -Path $tempFile -TemplateName "fs_powerschool_nonapi_report_students" -WarningVariable +warnings
                
                # Assert
                $warnings | Should -Not -BeNullOrEmpty
                $warnings | Where-Object { $_ -match "Failed to convert '12/31/1999' to datetime using.*format" } | Should -Not -BeNullOrEmpty
                $result.Students.Count | Should -Be 1
                $result.Students[0].FirstName | Should -Be "John"
                $result.Students[0].LastName | Should -Be "Doe"
                # DOB should remain default value due to parsing failure
                $result.Students[0].DOB | Should -Be ([datetime]::MinValue)
            }
            finally {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should parse datetime correctly when format matches" {
            # Arrange - Create test CSV with dd/MM/yyyy format matching template
            $testCsvContent = @"
Student_Number,First_Name,Last_Name,DOB
12345,John,Doe,31/12/1999
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            $testCsvContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                # Act - Import with US format template (should parse correctly)
                $warnings = @()
                $result = Import-FSCsv -Path $tempFile -TemplateName "fs_powerschool_nonapi_report_students" -WarningVariable +warnings
                
                # Assert
                $result.Students.Count | Should -Be 1
                $result.Students[0].FirstName | Should -Be "John"
                $result.Students[0].LastName | Should -Be "Doe"
                # DOB should parse correctly
                $result.Students[0].DOB | Should -Be ([datetime]::new(1999, 12, 31))
                
                # Should not have datetime parsing warnings
                $dateTimeWarnings = $warnings | Where-Object { $_ -match "Failed to convert.*to datetime" }
                $dateTimeWarnings | Should -BeNullOrEmpty
            }
            finally {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}