## ADDED Requirements

### Requirement: Media Library UI SHALL support user-confirmed Bangumi matching
The media library page SHALL let the user search Bangumi candidates for a
local media item and confirm one candidate before a Bangumi provider binding is
saved.

#### Scenario: User confirms a Bangumi match
- **WHEN** the user searches candidates for a local media item and selects a
  Bangumi subject
- **THEN** the UI calls a Domain-facing media matching action
- **AND** the Domain layer saves a `userConfirmed` Bangumi `ProviderBinding`
  for that local media item
- **AND** the UI refreshes the media library projection without directly
  importing Bangumi HTTP client or transport classes

#### Scenario: User scans local media
- **WHEN** a media library scan imports local files
- **THEN** scan/import does not write remote Bangumi collection or episode
  progress
- **AND** candidates or bindings are only produced by an explicit local match
  action
