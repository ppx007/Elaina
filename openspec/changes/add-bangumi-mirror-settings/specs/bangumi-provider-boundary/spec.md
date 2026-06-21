## ADDED Requirements

### Requirement: Bangumi provider SHALL support an optional self-hosted mirror
The concrete Bangumi provider SHALL allow API and Bangumi image traffic to use a
user-configured mirror while keeping official Bangumi endpoints as the default.

#### Scenario: Mirror is disabled
- **WHEN** Bangumi metadata, auth, collection, or progress operations run
- **THEN** requests target official Bangumi API URLs and image URLs are preserved

#### Scenario: Mirror is enabled
- **WHEN** Bangumi metadata, auth, collection, or progress operations run
- **THEN** provider traffic uses the configured API mirror URL through
  ProviderGateway
- **AND** Bangumi image URLs are rewritten to the configured image mirror URL

#### Scenario: Mirror configuration is invalid
- **WHEN** the mirror is enabled with an invalid API or image mirror URL
- **THEN** the provider returns a normalized failure instead of dispatching a
  request or falling back to stale data
