## ADDED Requirements

### Requirement: Bangumi provider SHALL expose subject and episode lookup contracts
The system SHALL define Bangumi provider contracts for subject lookup and episode lookup as optional metadata enrichment.

#### Scenario: Subject metadata is requested
- **WHEN** Domain requests Bangumi subject metadata
- **THEN** the request is routed through a provider contract rather than direct UI access to Bangumi APIs

### Requirement: Bangumi auth and progress sync MUST be optional
The system MUST define Bangumi OAuth/session and progress-sync contracts without making authentication or progress sync a prerequisite for playback.

#### Scenario: User is not authenticated with Bangumi
- **WHEN** playback starts without Bangumi authentication
- **THEN** playback remains available and Bangumi progress sync is treated as unavailable enrichment

### Requirement: Bangumi traffic MUST use ProviderGateway
Bangumi provider traffic MUST use `ProviderGateway` for rate policy, retry, cache, deduplication, and normalized failure behavior.

#### Scenario: Bangumi provider is registered
- **WHEN** the Bangumi provider is added
- **THEN** it registers a rate policy and sends provider-facing requests through `ProviderGateway`
