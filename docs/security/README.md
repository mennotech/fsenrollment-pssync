# Security & Credential Management

This directory contains security documentation and credential management guides.

## 🔒 Documentation

- **[Secure Credential Management](Secure-Credential-Management.md)** - Comprehensive guide to secure credential handling
  - Environment variable management
  - `.env` file configuration
  - SecureString encryption
  - Cross-platform compatibility
  - Production deployment strategies

- **[Credentials Quick Reference](CREDENTIALS_QUICK_REF.md)** - Quick reference for credential setup
  - Fast setup steps
  - Common configurations
  - Troubleshooting

- **[Secure Credentials Implementation](SECURE_CREDENTIALS_IMPLEMENTATION.md)** - Technical implementation details
  - Architecture and design decisions
  - Security best practices
  - Code implementation

## 🔐 Security Best Practices

1. **Never commit credentials** to version control
2. **Use `.env` files** for local development (already in `.gitignore`)
3. **Clear environment variables** after loading credentials
4. **Use SecureString** for in-memory credential storage
5. **Enable pre-commit hooks** to scan for credential leaks
6. **Rotate credentials** regularly in production

## Quick Start

```powershell
# 1. Create .env file from template
Copy-Item config\.env.example config\.env
# Edit config\.env with your credentials

# 2. Import module and connect (auto-loads .env)
Import-Module ./fsenrollment-pssync/FSEnrollment-PSSync.psd1
Connect-PowerSchool
```

## Need Help?

See the full [Secure Credential Management](Secure-Credential-Management.md) guide for detailed instructions.
