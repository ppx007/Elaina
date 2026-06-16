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

### Requirement: Bangumi provider runtime SHALL use deterministic request keys
Bangumi provider runtime operations SHALL construct provider request keys for subject lookup, subject search, episode lookup, session lookup, and progress sync without exposing concrete HTTP endpoint paths to Domain or UI layers.

#### Scenario: Subject metadata is looked up
- **WHEN** Bangumi subject metadata is requested through the runtime
- **THEN** the provider executes a ProviderGateway request under the Bangumi provider id with a deterministic subject request key

### Requirement: Bangumi runtime auth SHALL remain optional enrichment
Bangumi runtime auth and progress sync SHALL remain optional enrichment and MUST NOT be required for playback, subtitle parsing, subtitle rendering descriptors, Dandanplay matching, RSS, BT, online-rule runtime, or local media flows.

#### Scenario: Bangumi auth is absent
- **WHEN** the Bangumi auth provider reports no current session
- **THEN** Domain receives a normalized unauthenticated result and other non-Bangumi features remain outside the failure path

### Requirement: Bangumi runtime SHALL normalize gateway failures
Bangumi runtime provider implementations SHALL convert ProviderGateway failures into `AcgProviderFailureKind` values before returning results to Domain.

#### Scenario: Gateway throttles a Bangumi request
- **WHEN** ProviderGateway reports a throttled Bangumi request
- **THEN** the Bangumi runtime returns an `AcgProviderFailure` with throttled semantics instead of leaking gateway exceptions

### Requirement: Bangumi concrete client SHALL remain a Provider-layer detail
The system SHALL provide a concrete Bangumi API client behind the
`BangumiProvider` and `BangumiAuthProvider` contracts without exposing HTTP
endpoint paths, transport classes, OAuth tokens, or JSON payload shapes to
Domain, UI, Playback, Storage, Streaming, or Network runtime callers.

#### Scenario: Domain requests Bangumi metadata
- **WHEN** Domain asks for subject, search, episode, session, or progress data
- **THEN** it receives `AcgProviderResult` values through Bangumi provider
  contracts and does not import the concrete Bangumi API client or transport
  types

### Requirement: Bangumi concrete client SHALL normalize API failures
The concrete Bangumi client SHALL convert HTTP status failures, malformed JSON,
missing required fields, unauthenticated operations, and transport exceptions
into provider-normalized failures before results cross the provider boundary.

#### Scenario: Bangumi API rejects a request
- **WHEN** the concrete client receives an unauthorized, not-found, throttled,
  retryable, malformed, or terminal API response
- **THEN** callers receive an `AcgProviderFailure` with normalized semantics
  rather than raw HTTP, JSON, socket, or transport exceptions

