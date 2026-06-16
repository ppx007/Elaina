## ADDED Requirements

### Requirement: OpenSubtitles concrete provider SHALL remain a Provider-layer detail
The system SHALL provide a concrete OpenSubtitles API client behind the
`SubtitleProvider` contract without exposing HTTP endpoint paths, transport
classes, API keys, download-link payloads, or JSON payload shapes to Domain,
UI, Playback, Storage, Streaming, or Network runtime callers.

#### Scenario: Domain requests provider subtitles
- **WHEN** Domain searches or retrieves provider subtitles
- **THEN** it receives `AcgProviderResult` values through `SubtitleProvider`
  and does not import the concrete OpenSubtitles API client or transport types

### Requirement: OpenSubtitles concrete provider SHALL normalize API failures
The concrete OpenSubtitles provider SHALL convert HTTP status failures,
malformed JSON, missing required fields, absent API keys, and transport
exceptions into provider-normalized failures before results cross the provider
boundary.

#### Scenario: OpenSubtitles API rejects a request
- **WHEN** the concrete provider receives unauthorized, not-found, throttled,
  retryable, malformed, or terminal API responses
- **THEN** callers receive an `AcgProviderFailure` with normalized semantics
  rather than raw HTTP, JSON, socket, or transport exceptions
