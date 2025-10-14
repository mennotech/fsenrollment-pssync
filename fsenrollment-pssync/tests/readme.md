# tests

This directory contains Pester tests for the fsenrollment-pssync module.

## Guidelines

- Use Pester 5.x syntax
- Name test files with `.Tests.ps1` suffix
- Organize tests using `Describe` and `Context` blocks
- Follow the Arrange-Act-Assert (AAA) pattern
- Use `BeforeAll`, `BeforeEach`, `AfterEach`, and `AfterAll` for setup/teardown
- Mock external dependencies (API calls, file system operations)
- Test both success and failure scenarios

## Running Tests

```powershell
# Run all tests
Invoke-Pester

# Run tests with code coverage
Invoke-Pester -CodeCoverage 'fsenrollment-pssync.psm1'

# Run specific test file
Invoke-Pester -Path ./tests/Get-StudentData.Tests.ps1
```

## Test Structure Example

```powershell
BeforeAll {
    Import-Module ./fsenrollment-pssync.psd1 -Force
}

Describe 'Get-StudentData' {
    Context 'When valid parameters are provided' {
        It 'Should return student data' {
            # Arrange
            $studentId = '12345'
            
            # Act
            $result = Get-StudentData -StudentId $studentId
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'When invalid parameters are provided' {
        It 'Should throw an error' {
            # Arrange & Act & Assert
            { Get-StudentData -StudentId '' } | Should -Throw
        }
    }
}
```

## Code Coverage

Aim for high test coverage, especially for:
- Public functions (target: >90%)
- Critical sync logic
- Error handling paths
- Data validation functions
