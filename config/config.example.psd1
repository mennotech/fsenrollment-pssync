@{
    # PowerSchool API Configuration
    PowerSchool = @{
        # Base URL for PowerSchool API (update with your instance URL)
        BaseUrl = 'https://your-powerschool-instance.com/ws/v1'
        
        # OAuth Client ID (store actual value in secure credential storage)
        ClientId = 'your-client-id-here'
        
        # API timeout in seconds
        Timeout = 30
        
        # Number of retry attempts for failed API calls
        RetryAttempts = 3
        
        # Initial retry delay in seconds (uses exponential backoff)
        RetryDelaySeconds = 5
        
        # Maximum batch size for bulk operations
        BatchSize = 100
    }
    
    # Final Site Enrollment Data Configuration
    FinalSiteEnrollment = @{
        # Local path for CSV data files
        DataPath = './data/incoming'
        
        # File name patterns to monitor
        FilePatterns = @('students_*.csv', 'staff_*.csv', 'enrollments_*.csv')
    }
    
    # Logging Configuration
    Logging = @{
        # Log level: Debug, Info, Warning, Error
        LogLevel = 'Info'
        
        # Path where log files are stored
        LogPath = './logs'
        
        # Maximum log file size in MB before rotation
        MaxLogSizeMB = 10
        
        # Number of days to retain log files
        RetentionDays = 30
        
        # Enable verbose console output
        VerboseConsole = $true
    }
    
    # Synchronization Configuration
    Sync = @{
        # Enable dry-run mode (no changes applied to PowerSchool)
        DryRun = $false
        
        # Enable approval workflow (changes must be reviewed before applying)
        EnableApprovalWorkflow = $true
        
        # Approval file path (stores pending changes)
        ApprovalFilePath = './data/pending_changes.json'
        
        # Enable automatic archival of processed files
        AutoArchive = $true
        
        # Archive path for processed files
        ArchivePath = './data/archive'
        
        # Maximum concurrent API requests
        MaxConcurrentRequests = 5
        
        # Enable change detection (only sync differences)
        EnableChangeDetection = $true
    }
    
    # Data Validation Configuration
    Validation = @{
        # Required fields for student records
        RequiredStudentFields = @('StudentId', 'FirstName', 'LastName', 'Grade')
        
        # Enable strict validation (fail on any validation error)
        StrictValidation = $true
        
        # Maximum allowed validation errors before stopping
        MaxValidationErrors = 10
        
        # Enable data sanitization
        EnableSanitization = $true
    }
    
    # Email Notification Configuration (optional)
    Email = @{
        # Enable email notifications
        Enabled = $false
        
        # SMTP server configuration
        SmtpServer = 'smtp.example.com'
        SmtpPort = 587
        SmtpUseSsl = $true
        
        # Email addresses
        FromAddress = 'powerschool-sync@example.com'
        ToAddresses = @('admin@example.com')
        
        # Send notification on success
        NotifyOnSuccess = $false
        
        # Send notification on error
        NotifyOnError = $true
    }
}
