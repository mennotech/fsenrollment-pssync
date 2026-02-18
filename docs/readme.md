# Documentation

This directory contains all project documentation organized by category.

## 📁 Documentation Structure

```
docs/
├── guides/
│   ├── user/                           # End-user guides
│   │   ├── PowerSchool-ChangeDetection-Usage.md
│   │   ├── CSV-Parsing-Examples.md
│   │   ├── Invoke-PowerQuery-Examples.md
│   │   └── Invoke-PowerQuery-Pagination-Examples.md
│   ├── developer/                      # Developer guides
│   │   ├── Submit-PSStudentChange-Usage.md
│   │   ├── Invoke-PSRequest-Usage.md
│   │   └── DateTime-Format-Configuration.md
│   └── README.md
├── security/                           # Security documentation
│   ├── Secure-Credential-Management.md
│   ├── CREDENTIALS_QUICK_REF.md
│   ├── SECURE_CREDENTIALS_IMPLEMENTATION.md
│   └── README.md
├── api/                                # API documentation
│   ├── PowerSchool-API-Testing-Results.md
│   ├── PowerSchool-Student-API-Implementation.md
│   ├── powerschool_api.yaml
│   └── README.md
├── updates/                            # Important updates
│   ├── PowerQuery-Association-IDs-Update.md
│   └── README.md
├── powerschool api plugin/             # PowerQuery plugin files
│   ├── plugin.xml
│   ├── queries_root/
│   └── *.named_queries.md
└── powerschool-api-docs/               # Complete API reference
    ├── plugins/
    └── README.md
```

## 📖 Quick Links

### 🎯 User Guides (`guides/user/`)
- **[PowerSchool Change Detection Usage](guides/user/PowerSchool-ChangeDetection-Usage.md)** - Comprehensive guide for detecting changes in student and contact data
- **[CSV Parsing Examples](guides/user/CSV-Parsing-Examples.md)** - Examples of importing and parsing CSV data
- **[Invoke-PowerQuery Examples](guides/user/Invoke-PowerQuery-Examples.md)** - Using PowerQuery to retrieve PowerSchool data
- **[Invoke-PowerQuery Pagination Examples](guides/user/Invoke-PowerQuery-Pagination-Examples.md)** - Handling large datasets with pagination

### 🔒 Security & Credentials (`security/`)
- **[Secure Credential Management](security/Secure-Credential-Management.md)** - Comprehensive guide to secure credential handling
- **[Credentials Quick Reference](security/CREDENTIALS_QUICK_REF.md)** - Quick reference for credential setup
- **[Secure Credentials Implementation](security/SECURE_CREDENTIALS_IMPLEMENTATION.md)** - Technical implementation details

### ⚠️ Important Updates (`updates/`)
- **[PowerQuery Association IDs Update](updates/PowerQuery-Association-IDs-Update.md)** - **CRITICAL:** Required PowerQuery plugin update for contact email/phone/address operations (Feb 2026)

### 👨‍💻 Developer Guides (`guides/developer/`)
- **[Submit Student Changes Usage](guides/developer/Submit-PSStudentChange-Usage.md)** - Guide for submitting student changes to PowerSchool
- **[Invoke-PSRequest Usage](guides/developer/Invoke-PSRequest-Usage.md)** - Making PowerSchool API requests with retry logic
- **[DateTime Format Configuration](guides/developer/DateTime-Format-Configuration.md)** - Configuring date/time formats in templates

### 🔌 API Documentation (`api/`)
- **[PowerSchool API Testing Results](api/PowerSchool-API-Testing-Results.md)** - API testing results and findings
- **[PowerSchool Student API Implementation](api/PowerSchool-Student-API-Implementation.md)** - Student API implementation details
- **[PowerSchool API OpenAPI Spec](api/powerschool_api.yaml)** - OpenAPI 3.0 specification
- **[PowerSchool API Reference](powerschool-api-docs/)** - Complete PowerSchool API documentation

### 🔧 PowerSchool Plugin (`powerschool api plugin/`)
- **[Plugin Files](powerschool%20api%20plugin/)** - PowerQuery plugin XML files and documentation

## 📝 Documentation Guidelines

When adding or updating documentation:

1. **Choose the Right Location:**
   - User-facing guides → `guides/user/`
   - Technical/developer docs → `guides/developer/`
   - Security-related → `security/`
   - API specifications → `api/`
   - Breaking changes/updates → `updates/`

2. **Follow Best Practices:**
   - Use Markdown format (.md)
   - Include clear examples with code blocks
   - Add troubleshooting sections for common issues
   - Keep documentation in sync with code changes
   - Use diagrams where helpful (Mermaid, PlantUML)
   - Include "Last Updated" dates for critical docs

3. **Document Structure:**
   - Start with a clear title and brief overview
   - Include a table of contents for longer docs
   - Provide step-by-step instructions
   - Add prerequisites and requirements
   - Include error messages and solutions

## Contributing

When adding new features or making changes:
1. Update relevant documentation
2. Add examples for new functionality
3. Update troubleshooting guide if new issues may arise
4. Review documentation for accuracy
