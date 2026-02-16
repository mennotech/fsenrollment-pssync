function ConvertFrom-SecureCredential {
    <#
    .SYNOPSIS
        Converts a SecureString credential to plain text for use in API calls.
    
    .DESCRIPTION
        This helper function safely converts SecureString values back to plain text
        when needed for API authentication. The plain text value should be used
        immediately and not stored. This function uses BSTR marshaling which is
        more secure than other conversion methods.
    
    .PARAMETER SecureString
        The SecureString to convert to plain text.
    
    .EXAMPLE
        $credentials = Import-EnvironmentCredentials
        $clientSecret = ConvertFrom-SecureCredential -SecureString $credentials.PowerSchoolClientSecret
        
        # Use immediately in API call
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ Authorization = "Bearer $clientSecret" }
        
        # Clear the variable immediately after use
        $clientSecret = $null
    
    .OUTPUTS
        String (plain text credential)
    
    .NOTES
        - Use this function sparingly and only when absolutely necessary
        - Clear the resulting variable immediately after use
        - Never log or store the plain text value
        - Consider using PSCredential objects when possible for built-in cmdlets
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [SecureString]$SecureString
    )
    
    process {
        try {
            # Use BSTR marshaling for secure conversion
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            
            return $plainText
        }
        finally {
            # Always zero out the BSTR memory
            if ($bstr) {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
    }
}
