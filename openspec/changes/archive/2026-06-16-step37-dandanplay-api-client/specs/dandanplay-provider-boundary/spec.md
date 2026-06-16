## ADDED Requirements

### Requirement: Dandanplay concrete client SHALL remain a Provider-layer detail
The system SHALL provide a concrete Dandanplay API client behind the
`DandanplayProvider` and `DandanplayCommentProvider` contracts without exposing
HTTP endpoint paths, transport classes, app credentials, bearer tokens, or JSON
payload shapes to Domain, UI, Playback, Storage, Streaming, or Network runtime
callers.

#### Scenario: Domain requests Dandanplay enrichment
- **WHEN** Domain asks for match, search, comments, or comment-posting behavior
- **THEN** it receives `AcgProviderResult` values through Dandanplay contracts
  and does not import the concrete Dandanplay API client or transport types

### Requirement: Dandanplay concrete client SHALL normalize API failures
The concrete Dandanplay client SHALL convert HTTP status failures, API
`success/errorCode` failures, malformed JSON, missing required fields,
unauthenticated posting, and transport exceptions into provider-normalized
failures before results cross the provider boundary.

#### Scenario: Dandanplay API rejects a request
- **WHEN** the concrete client receives an unauthorized, not-found, throttled,
  retryable, malformed, or terminal API response
- **THEN** callers receive an `AcgProviderFailure` with normalized semantics
  rather than raw HTTP, JSON, socket, or transport exceptions
