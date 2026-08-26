#Requires -Version 7.0

<#
.SYNOPSIS
    Execute a direct API request to PowerSchool with automatic authorization handling.

.DESCRIPTION
    Makes HTTP requests to the PowerSchool API with automatic authorization header
    management. Handles authentication, retry logic, rate limiting, and error handling
    using the established PowerSchool connection from Connect-PowerSchool.
    
    This function provides a convenient way to make custom API calls to PowerSchool
    endpoints that may not have dedicated wrapper functions.

.PARAMETER Endpoint
    The API endpoint path (e.g., "/ws/v1/student/1234" or "/ws/contacts/contact/5678").
    Can be provided with or without the leading slash. The base URL from the connection
    is automatically prepended.

.PARAMETER Method
    HTTP method to use for the request. Valid values are: Get, Post, Put, Patch, Delete.
    Default is Get.

.PARAMETER Body
    Request body for POST/PUT/PATCH requests. Can be a hashtable, PSCustomObject, or
    JSON string. Hashtables and objects will be automatically converted to JSON.

.PARAMETER MaxRetries
    Maximum number of retry attempts for failed requests. Default is 3.
    Retries are performed for rate limiting (429) and server errors (5xx).

.PARAMETER InitialRetryDelaySeconds
    Initial retry delay in seconds with exponential backoff. Default is 5.
    Each subsequent retry doubles the delay time.

.INPUTS
    None. This function does not accept pipeline input.

.OUTPUTS
    PSCustomObject. The parsed JSON response from the PowerSchool API.

.EXAMPLE
    Invoke-PSRequest -Endpoint "/ws/v1/student/1234"
    
    Retrieves student data for student ID 1234 using a GET request.

.EXAMPLE
    Invoke-PSRequest -Endpoint "/ws/contacts/contact/5678" -Method Get
    
    Retrieves contact data for contact ID 5678.

.EXAMPLE
    $body = @{
        name = @{
            first_name = "John"
            last_name = "Doe"
        }
        contact_info = @{
            email = "john.doe@example.com"
        }
    }
    Invoke-PSRequest -Endpoint "/ws/contacts/contact" -Method Post -Body $body
    
    Creates a new contact with the specified data.

.EXAMPLE
    $updates = @{
        contact_info = @{
            email = "newemail@example.com"
        }
    }
    Invoke-PSRequest -Endpoint "/ws/contacts/contact/5678" -Method Patch -Body $updates
    
    Updates the email address for contact ID 5678.

.EXAMPLE
    Invoke-PSRequest -Endpoint "ws/v1/district/student/count" -MaxRetries 5
    
    Gets the student count with increased retry attempts (5 instead of default 3).

.EXAMPLE
    $result = Invoke-PSRequest -Endpoint "/ws/schema/query/com.scs.dats.students.contacts.email"
    $result.record
    
    Executes a PowerQuery and accesses the returned records.

.NOTES
    This function requires an active PowerSchool connection established via Connect-PowerSchool.
    The function automatically:
    - Validates the connection and refreshes the token if needed
    - Adds the Authorization header with the current access token
    - Sets appropriate Content-Type and Accept headers for JSON
    - Implements retry logic with exponential backoff
    - Handles rate limiting (429) and server errors (5xx)
    - Respects Retry-After headers when present

.LINK
    Connect-PowerSchool
.LINK
    Invoke-PowerQuery
#>
function Invoke-PSRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Get', 'Post', 'Put', 'Patch', 'Delete')]
        [string]$Method = 'Get',

        [Parameter(Mandatory = $false)]
        [object]$Body,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$InitialRetryDelaySeconds = 5
    )

    begin {
        Write-Verbose "Starting Invoke-PSRequest for endpoint: $Endpoint"
    }

    process {
        try {
            # Ensure connection is valid
            Test-PowerSchoolConnection

            # Get access token
            $accessToken = Get-PowerSchoolAccessToken
            
            # Build headers
            $headers = @{
                'Authorization' = "Bearer $accessToken"
                'Content-Type' = 'application/json'
                'Accept' = 'application/json'
            }

            # Normalize endpoint (remove leading slash if present, then add it back)
            $normalizedEndpoint = $Endpoint.TrimStart('/')
            $uri = "$script:PowerSchoolBaseUrl/$normalizedEndpoint"

            Write-Verbose "Making $Method request to: $uri"
            
            # Build parameters for the API request
            $apiParams = @{
                Uri = $uri
                Headers = $headers
                Method = $Method
                MaxRetries = $MaxRetries
                InitialRetryDelaySeconds = $InitialRetryDelaySeconds
            }

            # Add body if provided
            if ($Body) {
                $apiParams['Body'] = $Body
                
                # Log body content for debugging
                if ($Body -is [string]) {
                    Write-Verbose "Request Body: $Body"
                } else {
                    Write-Verbose "Request Body: $($Body | ConvertTo-Json -Depth 10 -Compress)"
                }
            }

            # Make the API request using the internal function with retry logic
            $response = Invoke-PowerSchoolApiRequest @apiParams
            
            Write-Verbose "Request completed successfully"
            return $response
        }
        catch {
            Write-Error "Failed to execute PowerSchool API request: $_"
            throw
        }
    }

    end {
        Write-Verbose "Invoke-PSRequest completed"
    }
}
