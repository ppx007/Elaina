# media-library-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-detail-library-seasonal. Update Purpose after archive.
## Requirements
### Requirement: Media library SHALL define local media identity and scan contracts
The system SHALL define local media identity, scan candidates, and media item contracts independently of provider metadata.

#### Scenario: Local scan finds a media file
- **WHEN** a local media scanner discovers a playable file
- **THEN** the file is represented as a media item candidate without requiring provider matching

### Requirement: Playback history SHALL support continue-watching state
The system SHALL define playback history and continue-watching contracts backed by Storage-layer responsibilities.

#### Scenario: Playback progress is recorded
- **WHEN** playback progress is saved for a media item
- **THEN** the media library can expose continue-watching state through Domain contracts

### Requirement: User-confirmed bindings MUST outrank automatic matches
The system MUST preserve user-confirmed provider bindings over automatically generated provider matches.

#### Scenario: Automatic match conflicts with user binding
- **WHEN** an automatic Bangumi match conflicts with a user-confirmed binding
- **THEN** the user-confirmed binding remains authoritative

### Requirement: Local media values SHALL be usable as playback handoff inputs
Local media identity and scan candidate contracts SHALL carry enough source information for a playback source handoff to prepare local file playback without requiring provider metadata, storage-backed library state, or network access.

#### Scenario: Scan candidate is selected for playback
- **WHEN** a user or test selects a media scan candidate with a file URI
- **THEN** the candidate can be passed to the playback source handoff without resolving Bangumi bindings, provider metadata, playback history, storage records, gateway requests, or network resources

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
