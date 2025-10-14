# PowerShell Classes

This directory contains PowerShell class definitions used by the fsenrollmentpssync module.

## Guidelines

- Use classes for complex data structures and business objects
- Define clear properties and methods
- Implement constructors when needed
- Add XML documentation comments for IntelliSense support
- Consider using `[ValidateScript()]` or custom validation

## Example Class Structure

```powershell
class Student {
    # Properties
    [string]$StudentId
    [string]$FirstName
    [string]$LastName
    [datetime]$EnrollmentDate

    # Constructor
    Student([string]$id, [string]$firstName, [string]$lastName) {
        $this.StudentId = $id
        $this.FirstName = $firstName
        $this.LastName = $lastName
    }

    # Methods
    [string] GetFullName() {
        return "$($this.FirstName) $($this.LastName)"
    }
}
```

## Usage

Classes defined here are automatically available when the module is imported.
