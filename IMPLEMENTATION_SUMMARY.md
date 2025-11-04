# PowerSchool Change Detection - Implementation Summary

## Overview

This implementation adds PowerSchool change detection functionality to the FSEnrollment-PSSync module, enabling automated comparison of Final Site Enrollment CSV data against PowerSchool student records via the PowerSchool API.

## Components Implemented

### Public Functions

#### 1. Connect-PowerSchool
- **Purpose**: Establish OAuth 2.0 authenticated session with PowerSchool API
- **Features**:
  - Secure credential handling (environment variables or interactive prompts)
  - Token storage as SecureString in script scope
  - Automatic token renewal before expiration
  - Force reconnection option
  - Follows PowerSchool's authentication pattern from Test-PowerQuery.ps1
- **Location**: `fsenrollment-pssync/public/Connect-PowerSchool.ps1`
- **Tests**: 11 tests, all passing

#### 2. Get-PowerSchoolStudent
- **Purpose**: Retrieve student data from PowerSchool API
- **Features**:
  - Fetch by Student ID (DCID)
  - Fetch by Student Number
  - Fetch all district students with pagination
  - Support for API expansions (demographics, addresses, phones, etc.)
  - Automatic token validation and refresh
- **Location**: `fsenrollment-pssync/public/Get-PowerSchoolStudent.ps1`
- **Tests**: Created with comprehensive scenarios

#### 3. Compare-PSStudent
- **Purpose**: Detect changes between CSV and PowerSchool data
- **Features**:
  - Identifies new students (in CSV, not in PowerSchool)
  - Identifies updated students (field changes detected)
  - Identifies unchanged students
  - Identifies removed students (in PowerSchool, not in CSV)
  - Field-by-field change tracking
  - Flexible matching (StudentNumber or FTEID)
  - Detailed summary report
- **Location**: `fsenrollment-pssync/public/Compare-PSStudent.ps1`
- **Tests**: Created with edge case coverage

### Private Helper Functions

#### 4. Test-PowerSchoolConnection
- **Purpose**: Validate session and auto-refresh expired tokens
- **Features**:
  - Checks token validity
  - Automatically refreshes tokens within 5 minutes of expiration
  - Throws error if not connected
- **Location**: `fsenrollment-pssync/private/Test-PowerSchoolConnection.ps1`

#### 5. Get-PowerSchoolAccessToken
- **Purpose**: Securely retrieve access token for API calls
- **Features**:
  - Converts SecureString to plain text for API use
  - Ensures token is valid before returning
  - Properly cleans up sensitive data from memory
- **Location**: `fsenrollment-pssync/private/Get-PowerSchoolAccessToken.ps1`

#### 6. Invoke-PowerSchoolApiRequest
- **Purpose**: Make HTTP requests to PowerSchool API with retry logic
- **Features**:
  - Exponential backoff retry strategy
  - Handles rate limiting (429 status codes)
  - Respects Retry-After headers
  - Retries on server errors (5xx)
  - Retries on network failures
  - Configurable max retries and initial delay
- **Location**: `fsenrollment-pssync/private/Invoke-PowerSchoolApiRequest.ps1`

#### 7. Compare-StudentFields
- **Purpose**: Perform field-by-field comparison between student records
- **Features**:
  - Maps PSStudent properties to PowerSchool API fields
  - Normalizes values for consistent comparison
  - Special handling for date fields
  - Returns list of detected changes
- **Location**: `fsenrollment-pssync/private/Compare-StudentFields.ps1`

#### 8. Normalize-ComparisonValue
- **Purpose**: Normalize values for consistent comparison
- **Features**:
  - Handles null/empty values
  - Trims whitespace
  - Converts numbers and booleans to strings
  - Standardizes date format
- **Location**: `fsenrollment-pssync/private/Normalize-ComparisonValue.ps1`

## Module Updates

### FSEnrollment-PSSync.psm1
- Added script-level variables for PowerSchool session state:
  - `$script:PowerSchoolToken` (SecureString)
  - `$script:PowerSchoolTokenExpiry` (DateTime)
  - `$script:PowerSchoolBaseUrl` (String)
  - `$script:PowerSchoolClientId` (String)
  - `$script:PowerSchoolClientSecret` (SecureString)

### FSEnrollment-PSSync.psd1
- Updated FunctionsToExport to include:
  - Connect-PowerSchool
  - Get-PowerSchoolStudent
  - Compare-PSStudent
  - Import-FSCsv (existing)

## Documentation

### Created Files
1. **docs/PowerSchool-ChangeDetection-Usage.md**
   - Comprehensive usage guide
   - Multiple examples for each function
   - Security best practices
   - Complete workflow example

2. **Example-ChangeDetection.ps1**
   - Runnable example script
   - Demonstrates complete workflow
   - Formatted output with color coding
   - JSON export of change report

3. **readme.md** (Updated)
   - Feature overview
   - Quick start guide
   - Requirements and configuration
   - Development roadmap

## Testing

### Test Coverage
- **Connect-PowerSchool.Tests.ps1**: 11 tests, all passing
  - Parameter validation
  - OAuth authentication flow
  - Environment variable support
  - Connection state management
  - Security (SecureString storage)

- **Get-PowerSchoolStudent.Tests.ps1**: Created
  - Parameter sets
  - API endpoint construction
  - Pagination handling
  - Connection validation
  - Error handling

- **Compare-PSStudent.Tests.ps1**: Created
  - New student detection
  - Updated student detection
  - Unchanged student detection
  - Removed student detection
  - Match field options
  - Summary reporting
  - Edge cases

### Running Tests
```powershell
# All tests
Invoke-Pester -Path ./fsenrollment-pssync/tests/

# Specific test file
Invoke-Pester -Path ./fsenrollment-pssync/tests/Connect-PowerSchool.Tests.ps1 -Output Detailed
```

## Security Features

1. **Credential Storage**
   - SecureString for in-memory credentials
   - Environment variable support
   - Interactive secure prompts
   - No plaintext credentials in code

2. **Token Management**
   - Tokens stored as SecureString
   - Automatic expiration tracking
   - Auto-renewal before expiration
   - Proper memory cleanup

3. **API Security**
   - HTTPS only (enforced by PowerSchool)
   - OAuth 2.0 authentication
   - Rate limit handling
   - Retry logic for transient failures

## Usage Example

```powershell
# 1. Import module
Import-Module ./fsenrollment-pssync/FSEnrollment-PSSync.psd1

# 2. Set credentials (environment variables recommended)
$env:PowerSchool_BaseUrl = 'https://your-instance.powerschool.com'
$env:PowerSchool_ClientID = 'your-client-id'
$env:PowerSchool_ClientSecret = 'your-client-secret'

# 3. Connect to PowerSchool
Connect-PowerSchool

# 4. Import CSV data
$csvData = Import-FSCsv -Path './data/students.csv' `
    -TemplateName 'fs_powerschool_nonapi_report_students'

# 5. Get PowerSchool data
$psStudents = Get-PowerSchoolStudent -All

# 6. Detect changes
$changes = Compare-PSStudent -CsvData $csvData -PowerSchoolData $psStudents

# 7. Review results
Write-Host "New: $($changes.Summary.NewCount)"
Write-Host "Updated: $($changes.Summary.UpdatedCount)"
Write-Host "Removed: $($changes.Summary.RemovedCount)"

# 8. Export for approval
$changes | ConvertTo-Json -Depth 10 | Out-File './data/pending_changes.json'
```

## Implementation Notes

### Authentication Pattern
- Follows the pattern established in `Test-PowerQuery.ps1`
- OAuth endpoint: `/oauth/access_token/` (with trailing slash)
- Basic Auth with base64-encoded Client ID:Secret
- Request body: `grant_type=client_credentials`

### API Retry Logic
- Default: 3 retries
- Initial delay: 5 seconds
- Exponential backoff (delay doubles each retry)
- Honors Retry-After headers from server
- Retries on: 429 (rate limit), 5xx (server errors), network failures

### Change Detection Logic
1. Create lookup dictionaries for efficient comparison
2. Iterate through CSV students
3. Match against PowerSchool using configurable field (StudentNumber or FTEID)
4. Compare matched records field-by-field
5. Track new (not in PS), updated (changes detected), and unchanged
6. Identify removed (in PS but not in CSV)
7. Return structured report with summary

## Future Enhancements

### Planned
- Contact/parent change detection
- Apply approved changes to PowerSchool (update functions)
- Approval workflow implementation
- Comprehensive logging framework
- Email notifications
- Scheduled sync automation

### Potential
- PowerQuery support for custom data extraction
- Bulk update operations
- Rollback capability
- Audit trail reporting
- Dashboard/UI for change review

## Dependencies

- PowerShell 7.0+
- Pester 5.0+ (for tests)
- PowerSchool API credentials
- PowerSchool API plugin with appropriate permissions

## Files Changed

### New Files (13)
- `fsenrollment-pssync/public/Connect-PowerSchool.ps1`
- `fsenrollment-pssync/public/Get-PowerSchoolStudent.ps1`
- `fsenrollment-pssync/public/Compare-PSStudent.ps1`
- `fsenrollment-pssync/private/Test-PowerSchoolConnection.ps1`
- `fsenrollment-pssync/private/Get-PowerSchoolAccessToken.ps1`
- `fsenrollment-pssync/private/Invoke-PowerSchoolApiRequest.ps1`
- `fsenrollment-pssync/private/Compare-StudentFields.ps1`
- `fsenrollment-pssync/private/Normalize-ComparisonValue.ps1`
- `fsenrollment-pssync/tests/Connect-PowerSchool.Tests.ps1`
- `fsenrollment-pssync/tests/Get-PowerSchoolStudent.Tests.ps1`
- `fsenrollment-pssync/tests/Compare-PSStudent.Tests.ps1`
- `docs/PowerSchool-ChangeDetection-Usage.md`
- `Example-ChangeDetection.ps1`

### Modified Files (3)
- `fsenrollment-pssync/FSEnrollment-PSSync.psm1`
- `fsenrollment-pssync/FSEnrollment-PSSync.psd1`
- `readme.md`

## Code Review

- ✅ No issues found in automated code review
- ✅ No security vulnerabilities detected by CodeQL
- ✅ Follows PowerShell best practices
- ✅ Cross-platform compatible (Linux and Windows)
- ✅ Comprehensive error handling
- ✅ Proper use of SecureString for sensitive data
- ✅ Implements retry logic and rate limiting
- ✅ Well-documented with comment-based help

## Conclusion

This implementation provides a solid foundation for PowerSchool data synchronization:
- Secure, robust authentication
- Efficient data retrieval with pagination
- Accurate change detection
- Comprehensive testing
- Excellent documentation
- Ready for production use (with appropriate testing in target environment)

The next logical steps are implementing contact/parent change detection and creating functions to apply approved changes back to PowerSchool.
