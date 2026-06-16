## ADDED Requirements

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
