# PowerSchool API Documentation

This directory contains PowerSchool API documentation, specifications, and implementation guides.

## 📄 Documentation

- **[PowerSchool API Testing Results](PowerSchool-API-Testing-Results.md)** - API testing results, findings, and recommendations
- **[PowerSchool Student API Implementation](PowerSchool-Student-API-Implementation.md)** - Student API implementation details and patterns
- **[PowerSchool API OpenAPI Spec](powerschool_api.yaml)** - OpenAPI 3.0 specification for PowerSchool APIs

## 🔌 API References

- **[PowerSchool API Docs](../powerschool-api-docs/)** - Complete PowerSchool API reference documentation
  - Contact API
  - Student API
  - District API
  - Authentication

## 🔧 PowerSchool Plugin

- **[PowerQuery Plugin](../powerschool%20api%20plugin/)** - PowerQuery plugin files
  - `plugin.xml` - Plugin manifest
  - `queries_root/` - PowerQuery definitions
  - Named query documentation

## Key API Endpoints

### Student API
- `GET /ws/v1/student/{id}` - Get student by ID
- `PATCH /ws/v1/student/{id}` - Update student
- `GET /ws/v1/district/student/count` - Get student count

### Contact API
- `GET /ws/contacts/{contactId}` - Get contact by ID
- `POST /ws/contacts/contact` - Create new contact
- `PUT /ws/contacts/{contactId}/emails/{contactEmailId}` - Update email
- `DELETE /ws/contacts/{contactId}/emails/{contactEmailId}` - Delete email

### Authentication
- `POST /oauth/access_token` - Get OAuth access token

## Usage Examples

See the [User Guides](../guides/user/) for detailed examples of using these APIs.

## Important Notes

⚠️ **Association IDs Required:** Contact API PUT/DELETE operations require association IDs, not entity IDs. See [PowerQuery Association IDs Update](../updates/PowerQuery-Association-IDs-Update.md) for details.
