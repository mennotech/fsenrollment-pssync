# Invoke-PSRequest Usage Examples

This document provides examples of using the `Invoke-PSRequest` function to make direct API calls to PowerSchool.

## Overview

`Invoke-PSRequest` is a general-purpose function for making HTTP requests to the PowerSchool API. It automatically handles:
- Authentication and authorization headers
- Token refresh if needed
- Retry logic with exponential backoff
- Rate limiting (429) and server error (5xx) handling
- JSON request/response formatting

## Prerequisites

You must connect to PowerSchool before using this function:

```powershell
Connect-PowerSchool
```

## Basic Examples

### GET Request - Retrieve a Contact

```powershell
# Get contact by ID
$contact = Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905'
$contact | ConvertTo-Json -Depth 5
```

### GET Request - Retrieve a Student

```powershell
# Get student by ID
$student = Invoke-PSRequest -Endpoint '/ws/v1/student/1234'
$student.name
```

### GET Request - With Verbose Output

```powershell
# View detailed request information
$contact = Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905' -Verbose
```

## POST Request Examples

### Create a New Contact

```powershell
# Define the contact data
$newContact = @{
    name = @{
        first_name = 'John'
        last_name = 'Doe'
    }
    contact_info = @{
        email = 'john.doe@example.com'
        phone = '555-1234'
    }
}

# Create the contact
$result = Invoke-PSRequest -Endpoint '/ws/contacts/contact' -Method Post -Body $newContact
Write-Host "Created contact with ID: $($result.contactId)"
```

## PATCH Request Examples

### Update Contact Information

```powershell
# Define updates
$updates = @{
    contact_info = @{
        email = 'newemail@example.com'
    }
}

# Update the contact
$result = Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905' -Method Patch -Body $updates
```

### Update Student Address

```powershell
# Define address updates
$addressUpdates = @{
    addresses = @(
        @{
            street = '123 Main St'
            city = 'Springfield'
            state = 'IL'
            postalCode = '62701'
        }
    )
}

# Update student address
$result = Invoke-PSRequest -Endpoint '/ws/v1/student/1234' -Method Patch -Body $addressUpdates
```

## PUT Request Examples

### Replace Contact Data

```powershell
# Define complete contact data
$contactData = @{
    name = @{
        first_name = 'Jane'
        last_name = 'Smith'
    }
    contact_info = @{
        email = 'jane.smith@example.com'
        phone = '555-5678'
    }
}

# Replace contact (PUT replaces entire resource)
$result = Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905' -Method Put -Body $contactData
```

## DELETE Request Examples

### Delete a Contact

```powershell
# Delete a contact by ID
$result = Invoke-PSRequest -Endpoint '/ws/contacts/contact/9999' -Method Delete
```

## PowerQuery Examples

### Execute a PowerQuery

```powershell
# Execute a PowerQuery with parameters
$queryParams = @{
    id = '12345'
    status = 'active'
}

$result = Invoke-PSRequest `
    -Endpoint '/ws/schema/query/com.scs.dats.students.bygrade' `
    -Method Post `
    -Body $queryParams

# Access records
$result.record | Format-Table
```

## Advanced Examples

### Custom Retry Configuration

```powershell
# Use custom retry settings for unreliable connections
$result = Invoke-PSRequest `
    -Endpoint '/ws/v1/student/1234' `
    -MaxRetries 5 `
    -InitialRetryDelaySeconds 10
```

### Error Handling

```powershell
try {
    $contact = Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905'
    Write-Host "Contact found: $($contact.firstName) $($contact.lastName)"
}
catch {
    Write-Error "Failed to retrieve contact: $_"
}
```

### Batch Operations

```powershell
# Process multiple contacts
$contactIds = @(7905, 7906, 7907)
$contacts = foreach ($id in $contactIds) {
    try {
        Invoke-PSRequest -Endpoint "/ws/contacts/contact/$id"
    }
    catch {
        Write-Warning "Failed to retrieve contact $id: $_"
        $null
    }
}

$contacts | Where-Object { $_ -ne $null } | Format-Table contactId, firstName, lastName
```

## Comparing with Other Functions

### Invoke-PSRequest vs Invoke-PowerQuery

- Use `Invoke-PowerQuery` for executing named PowerQueries with automatic pagination support
- Use `Invoke-PSRequest` for direct API endpoint access and CRUD operations

```powershell
# Using Invoke-PowerQuery (easier for PowerQueries)
$students = Invoke-PowerQuery -PowerQueryName 'com.scs.dats.students.all' -AllRecords

# Using Invoke-PSRequest (more control)
$student = Invoke-PSRequest -Endpoint '/ws/v1/student/1234'
```

### Invoke-PSRequest vs Submit-PSContactChange

- Use `Submit-PSContactChange` for high-level contact change operations with validation
- Use `Invoke-PSRequest` for low-level API access or custom operations

```powershell
# Using Submit-PSContactChange (recommended for batch changes)
Submit-PSContactChange -JsonPath '.\data\pending\contact-changes.json'

# Using Invoke-PSRequest (for individual updates)
Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905' -Method Patch -Body $updates
```

## Tips and Best Practices

1. **Endpoint Paths**: You can include or omit the leading slash - both work:
   ```powershell
   Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905'
   Invoke-PSRequest -Endpoint 'ws/contacts/contact/7905'  # Same result
   ```

2. **JSON Bodies**: Bodies are automatically converted to JSON:
   ```powershell
   # Both work - hashtable is converted automatically
   $body = @{ field = 'value' }
   Invoke-PSRequest -Endpoint '/endpoint' -Method Post -Body $body
   
   # Or provide JSON string directly
   Invoke-PSRequest -Endpoint '/endpoint' -Method Post -Body '{"field":"value"}'
   ```

3. **Verbose Logging**: Use `-Verbose` to see detailed request/response information:
   ```powershell
   Invoke-PSRequest -Endpoint '/endpoint' -Verbose
   ```

4. **Default Method**: If not specified, GET is used:
   ```powershell
   # These are equivalent
   Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905'
   Invoke-PSRequest -Endpoint '/ws/contacts/contact/7905' -Method Get
   ```

5. **Error Handling**: Always wrap in try/catch for production code:
   ```powershell
   try {
       $result = Invoke-PSRequest -Endpoint '/endpoint'
   }
   catch {
       Write-Error "API call failed: $_"
       # Handle error appropriately
   }
   ```

## See Also

- [Connect-PowerSchool](PowerSchool-API-Testing-Results.md)
- [Invoke-PowerQuery](Invoke-PowerQuery-Examples.md)
- [Submit-PSContactChange](Submit-PSContactChange-Usage.md)
- [PowerSchool API Documentation](powerschool_api.yaml)
