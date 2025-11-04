#Requires -Version 7.0

<#
.SYNOPSIS
    Internal function to get the current PowerSchool access token.

.DESCRIPTION
    Retrieves the current PowerSchool access token as a plain string for use in API calls.
    Automatically ensures the token is valid before returning it.

.OUTPUTS
    String. The current access token.

.NOTES
    This is a private function used internally by other PowerSchool API functions.
    The token is stored as a SecureString but converted to plain text for API calls.
#>
function Get-PowerSchoolAccessToken {
    [CmdletBinding()]
    param()

    # Ensure connection is valid and token is fresh
    Test-PowerSchoolConnection

    # Convert SecureString token to plain text
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:PowerSchoolToken)
    try {
        $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        return $token
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
}
