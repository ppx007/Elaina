## MODIFIED Requirements

### Requirement: Seasonal indexer SHALL apply automatic matches without overriding user bindings
The system SHALL apply automatic Bangumi matches only through binding contracts
that preserve user-confirmed binding priority. The default automatic match
minimum confidence SHALL be named and shared across queue, worker, and runtime
bootstrap entry points rather than repeated as an inline literal.

#### Scenario: Automatic candidate conflicts with user binding
- **WHEN** the match worker finds an automatic candidate for an entry with an
  existing user-confirmed binding
- **THEN** the automatic match is skipped and the user-confirmed binding remains
  authoritative

#### Scenario: Automatic confidence default is reused
- **WHEN** queue, worker, or runtime bootstrap code constructs automatic Bangumi
  matching with the default confidence threshold
- **THEN** it references the named default threshold rather than duplicating a
  numeric literal
