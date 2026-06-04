# bangumi-provider-boundary Specification

## Purpose
TBD - created by archiving change bootstrap-acg-data-experience. Update Purpose after archive.
## Requirements
### Requirement: Bangumi provider SHALL expose subject and episode lookup contracts
The system SHALL define Bangumi provider contracts for subject lookup, subject search, and episode lookup as optional metadata enrichment, including queue-driven subject search for seasonal catalog entries.

#### Scenario: Subject metadata is requested
- **WHEN** Domain requests Bangumi subject metadata or seasonal match candidates
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

### Requirement: Bangumi match queue SHALL use provider-governed search
The system SHALL search Bangumi candidates for seasonal catalog entries through `BangumiProvider` and `ProviderGateway` instead of direct Domain or UI access to Bangumi APIs.

#### Scenario: Seasonal entry needs match candidates
- **WHEN** a Bangumi match queue worker processes a seasonal catalog entry
- **THEN** it searches subjects through Bangumi provider contracts and stores normalized candidates for later automatic or user-confirmed binding

