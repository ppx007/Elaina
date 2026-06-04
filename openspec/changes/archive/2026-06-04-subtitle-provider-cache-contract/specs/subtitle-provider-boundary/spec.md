## MODIFIED Requirements

### Requirement: SubtitleProvider SHALL discover external subtitle candidates
The system SHALL define `SubtitleProvider` contracts for external subtitle search and retrieval as provider-backed enrichment, and provider search results SHALL be cacheable through Storage-layer subtitle cache responsibilities.

#### Scenario: External subtitle search is requested
- **WHEN** Domain requests external subtitle candidates
- **THEN** the request is routed through a subtitle provider contract rather than direct UI provider access, and non-expired cached search results can satisfy repeated equivalent requests

### Requirement: SubtitleProvider traffic MUST use ProviderGateway
Subtitle provider traffic MUST use `ProviderGateway` for rate policy, retry, cache, deduplication, and normalized failure behavior, while durable subtitle search/content cache records remain owned by Storage-layer contracts.

#### Scenario: Subtitle provider is registered
- **WHEN** a subtitle provider is added
- **THEN** it registers a rate policy and sends provider-facing requests through `ProviderGateway` while using Storage contracts for durable subtitle cache state

### Requirement: Subtitle candidates SHALL remain parser-compatible
The system SHALL ensure subtitle provider results produce subtitle candidates compatible with `basic-subtitle-core` parsing contracts, including retrieval metadata needed for parser handoff.

#### Scenario: Provider returns subtitle file metadata
- **WHEN** a provider returns an external subtitle candidate
- **THEN** the candidate declares a supported subtitle format and can be passed to basic subtitle parsing after retrieval

## ADDED Requirements

### Requirement: SubtitleProvider orchestration SHALL remain Domain-facing
The system SHALL define Domain-facing orchestration for subtitle search, retrieval, cache lookup, and parser handoff without exposing concrete provider implementations to UI or playback code.

#### Scenario: Provider-backed subtitle is selected
- **WHEN** a provider subtitle candidate is selected for retrieval and parsing
- **THEN** Domain orchestration retrieves it through the provider contract, caches the retrieved content according to policy, and prepares a parser request without direct UI/provider implementation coupling
