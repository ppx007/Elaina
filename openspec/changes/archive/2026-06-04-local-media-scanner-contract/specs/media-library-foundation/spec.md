## ADDED Requirements

### Requirement: Media library scanner SHALL expose local scan results through Domain media contracts
The media library foundation SHALL expose local scan scopes, results, typed failures, and events through Domain media values before any storage-backed library state or provider metadata is required.

#### Scenario: Local scan completes with candidates
- **WHEN** a local media scan completes with file-backed candidates
- **THEN** the result contains existing `MediaScanCandidate` values and normalized typed failures without requiring database persistence, provider bindings, playback history, gateway requests, network resources, or UI state

### Requirement: Media scan failures SHALL carry typed failure semantics
The media library foundation SHALL provide scan failure semantics that distinguish unsupported schemes, excluded entries, unreadable entries, cancelled scans, and generic discovery failures without requiring callers to parse free-form messages.

#### Scenario: Unsupported entry fails during scan
- **WHEN** a scan entry cannot be represented as a supported local file candidate
- **THEN** the media scan failure identifies the failure category through Domain media data instead of a concrete platform exception or message-only error
