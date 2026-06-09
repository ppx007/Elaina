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

### Requirement: Dandanplay provider runtime SHALL use deterministic request keys
Dandanplay provider runtime operations SHALL construct provider request keys for local media match, subject search, comment retrieval, and comment posting without exposing concrete HTTP endpoint paths to Domain, Playback, or UI layers.

#### Scenario: Local media match is requested
- **WHEN** Dandanplay local media matching is requested through the runtime
- **THEN** the provider executes a ProviderGateway request under the Dandanplay provider id with a deterministic match request key

### Requirement: Dandanplay comments SHALL remain provider-governed enrichment
Dandanplay comment retrieval and posting SHALL remain optional provider-governed enrichment and MUST NOT be required for playback, subtitle parsing, subtitle rendering descriptors, Bangumi metadata, RSS, BT, online-rule runtime, or local media flows.

#### Scenario: Dandanplay comments are unavailable
- **WHEN** the Dandanplay comment provider cannot retrieve comments for an episode
- **THEN** Domain receives a normalized provider result and other non-Dandanplay features remain outside the failure path

### Requirement: Dandanplay runtime SHALL normalize gateway failures
Dandanplay runtime provider implementations SHALL convert ProviderGateway failures into `AcgProviderFailureKind` values before returning results to Domain.

#### Scenario: Gateway throttles a Dandanplay comment request
- **WHEN** ProviderGateway reports a throttled Dandanplay comments request
- **THEN** the Dandanplay runtime returns an `AcgProviderFailure` with throttled semantics instead of leaking gateway exceptions

