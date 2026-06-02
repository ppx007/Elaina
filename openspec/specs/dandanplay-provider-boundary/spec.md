# dandanplay-provider-boundary Specification

## Purpose
TBD - created by archiving change bootstrap-acg-data-experience. Update Purpose after archive.
## Requirements
### Requirement: Dandanplay provider SHALL expose match and search contracts
The system SHALL define Dandanplay match and search contracts as optional enrichment for local media.

#### Scenario: Local media is matched
- **WHEN** Domain requests Dandanplay matching for a local media item
- **THEN** the request is routed through a provider contract and does not block playback if matching fails

### Requirement: Dandanplay comments SHALL support retrieval and posting contracts
The system SHALL define Dandanplay comment retrieval and posting contracts without coupling UI code to Dandanplay APIs.

#### Scenario: User posts a danmaku comment
- **WHEN** a comment is posted to Dandanplay
- **THEN** the request is routed through Domain and Provider contracts rather than direct UI SDK access

### Requirement: Dandanplay traffic MUST use ProviderGateway
Dandanplay provider traffic MUST use `ProviderGateway` for rate policy, retry, cache, deduplication, and normalized failure behavior.

#### Scenario: Dandanplay provider is registered
- **WHEN** the Dandanplay provider is added
- **THEN** it registers a rate policy and sends provider-facing requests through `ProviderGateway`

