# Private Functions

This directory contains internal (non-exported) functions used by the fsenrollment-pssync module.

## Guidelines

- Private functions are not exported from the module
- Follow the same quality standards as public functions
- Use comment-based help for maintainability
- Keep functions focused on a single responsibility
- Private functions can call other private or public functions

## Naming

Private functions should still use Verb-Noun naming convention but do not need to be as strict with approved verbs since they are not exported.

## Testing

Private functions should be tested indirectly through public function tests, but can have dedicated unit tests if they contain complex logic.
