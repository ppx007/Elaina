## ADDED Requirements

### Requirement: Video detail runtime SHALL aggregate Bangumi rich metadata
The video-detail runtime SHALL project Bangumi subject stats, related persons,
related characters with voice actors, and related subjects into
`VideoDetailViewData` while preserving UI isolation from provider HTTP,
gateway, token, and JSON implementation details.

#### Scenario: Runtime loads complete Bangumi metadata
- **WHEN** the Bangumi provider returns subject, episode, staff, character/CV,
  and relation data for a detail id
- **THEN** the runtime returns a single detail view model containing playable
  episodes, tracking state, metadata stats, credits, characters, and related
  subjects

### Requirement: Optional Bangumi detail tables SHALL not break the main detail
The video-detail runtime SHALL treat staff, character/CV, and relation tables as
optional enrichments. A failure in one optional table MUST NOT make the subject
detail fail when the subject itself loaded successfully.

#### Scenario: Character table fails but subject loads
- **WHEN** subject metadata loads but the character table returns a throttled,
  retryable, unavailable, or terminal provider failure
- **THEN** the runtime still returns the subject detail and records an optional
  table failure for the UI to render as an empty/error state
