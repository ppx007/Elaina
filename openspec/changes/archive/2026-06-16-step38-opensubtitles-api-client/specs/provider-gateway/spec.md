## ADDED Requirements

### Requirement: ProviderGateway SHALL govern concrete OpenSubtitles traffic
Concrete OpenSubtitles API traffic SHALL be dispatched only from loader
functions owned by ProviderGateway requests under the OpenSubtitles provider
id.

#### Scenario: Concrete OpenSubtitles search executes
- **WHEN** the concrete provider searches subtitles or retrieves subtitle
  content
- **THEN** HTTP dispatch occurs inside a ProviderGateway request with the
  OpenSubtitles provider id, deterministic request key, cache policy, and
  deduplication window

### Requirement: OpenSubtitles concrete provider tests SHALL avoid live network dependency
Concrete OpenSubtitles provider validation SHALL use injectable fake transport
for request and response assertions instead of depending on live
OpenSubtitles service availability.

#### Scenario: Concrete provider tests run offline
- **WHEN** OpenSubtitles provider tests execute in CI or local validation
- **THEN** they verify request construction, headers, JSON mapping, and failure
  normalization through fake transport without external network access
