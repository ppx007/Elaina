## ADDED Requirements

### Requirement: SubtitleProvider SHALL discover external subtitle candidates
The system SHALL define `SubtitleProvider` contracts for external subtitle search and retrieval as provider-backed enrichment.

#### Scenario: External subtitle search is requested
- **WHEN** Domain requests external subtitle candidates
- **THEN** the request is routed through a subtitle provider contract rather than direct UI provider access

### Requirement: SubtitleProvider traffic MUST use ProviderGateway
Subtitle provider traffic MUST use `ProviderGateway` for rate policy, retry, cache, deduplication, and normalized failure behavior.

#### Scenario: Subtitle provider is registered
- **WHEN** a subtitle provider is added
- **THEN** it registers a rate policy and sends provider-facing requests through `ProviderGateway`

### Requirement: Subtitle candidates SHALL remain parser-compatible
The system SHALL ensure subtitle provider results produce subtitle candidates compatible with `basic-subtitle-core` parsing contracts.

#### Scenario: Provider returns subtitle file metadata
- **WHEN** a provider returns an external subtitle candidate
- **THEN** the candidate declares a supported subtitle format and can be passed to basic subtitle parsing after retrieval
