# subtitle-provider-boundary Specification

## Purpose
TBD - created by archiving change bootstrap-detail-library-seasonal. Update Purpose after archive.
## Requirements
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

### Requirement: SubtitleProvider orchestration SHALL remain Domain-facing
The system SHALL define Domain-facing orchestration for subtitle search, retrieval, cache lookup, and parser handoff without exposing concrete provider implementations to UI or playback code.

#### Scenario: Provider-backed subtitle is selected
- **WHEN** a provider subtitle candidate is selected for retrieval and parsing
- **THEN** Domain orchestration retrieves it through the provider contract, caches the retrieved content according to policy, and prepares a parser request without direct UI/provider implementation coupling

### Requirement: SubtitleProvider SHALL be consumable by subtitle-provider runtime
The subtitle provider boundary SHALL be directly consumable by the Step 15 subtitle-provider runtime through existing `SubtitleProvider`, `SubtitleSearchQuery`, `SubtitleProviderCandidate`, `RetrievedSubtitleFile`, and `SubtitleProviderCachePolicy` contracts.

#### Scenario: Runtime invokes subtitle provider search
- **WHEN** the subtitle-provider runtime searches provider subtitles
- **THEN** it receives provider candidates or normalized provider failures through existing provider result contracts without concrete UI, storage implementation, RSS, seasonal, BT, online-rule, diagnostics, network client, or native-player bindings

### Requirement: SubtitleProvider runtime consumption SHALL preserve ProviderGateway policy boundaries
Subtitle provider runtime consumption SHALL preserve provider registration, rate policy, retry policy, gateway cache policy, and normalized failure behavior rather than implementing provider-specific network governance inside Domain runtime code.

#### Scenario: Provider runtime depends on gateway-bound provider contract
- **WHEN** a subtitle provider is configured for runtime use
- **THEN** provider-facing traffic remains represented by `GatewayBoundProvider`, `ProviderRegistration`, and `SubtitleProviderCachePolicy` contracts while durable cache state remains outside concrete runtime ownership

### Requirement: SubtitleProvider retrieval SHALL remain parser-compatible
Provider subtitle retrieval through the runtime SHALL preserve supported subtitle format, source metadata, retrieved content, encoding hints, and candidate identity needed for parser handoff.

#### Scenario: Runtime retrieves subtitle file
- **WHEN** a provider candidate is retrieved through runtime actions
- **THEN** the retrieved file can be converted into a `SubtitleParseRequest` compatible with basic subtitle parser contracts without advanced caption rendering, native player startup, UI state, or provider implementation coupling

### Requirement: SubtitleProvider runtime checks MUST reject later-phase dependencies
Validation for the Step 15 subtitle-provider runtime slice MUST reject RSS, seasonal, BT, online-rule, diagnostics, advanced caption rendering, concrete Flutter UI, storage implementation, network client, MPV/VLC, native-player, scraping, and captcha automation dependencies.

#### Scenario: Subtitle provider runtime boundary is checked
- **WHEN** automation scans subtitle-provider runtime and checker files
- **THEN** forbidden later-phase and concrete implementation dependencies are rejected while provider subtitle contracts remain allowed

