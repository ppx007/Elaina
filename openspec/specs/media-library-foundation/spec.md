# media-library-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-detail-library-seasonal. Update Purpose after archive.
## Requirements
### Requirement: Media library SHALL define local media identity and scan contracts
The system SHALL define local media identity, scan candidates, and media item contracts independently of provider metadata, and the scan result SHALL remain importable into a persistent library catalog without requiring provider matching.

#### Scenario: Local scan finds a media file
- **WHEN** a local media scanner discovers a playable file
- **THEN** the file is represented as a media item candidate without requiring provider matching, and it can later be imported into the media library catalog through a storage-backed repository contract

### Requirement: Playback history SHALL support continue-watching state
The system SHALL define playback history and continue-watching contracts backed by Storage-layer responsibilities so persisted playback progress can be queried after restart.

#### Scenario: Playback progress is recorded
- **WHEN** playback progress is saved for a media item
- **THEN** the media library can expose continue-watching state through Domain contracts backed by stored playback history entries

### Requirement: User-confirmed bindings MUST outrank automatic matches
The system MUST preserve user-confirmed provider bindings over automatically generated provider matches, and the binding contract SHALL remain stable when persisted through Storage-layer responsibilities.

#### Scenario: Automatic match conflicts with user binding
- **WHEN** an automatic Bangumi match conflicts with a user-confirmed binding
- **THEN** the user-confirmed binding remains authoritative after persistence and derived views refresh

### Requirement: Media library SHALL persist catalog items and batch imports
The system SHALL define repository contracts for storing, retrieving, listing, updating, and removing media library items, and for importing scan candidates into the catalog with deterministic deduplication and result reporting.

#### Scenario: A scan import creates catalog entries
- **WHEN** a batch of local media scan candidates is imported into the catalog
- **THEN** the repository creates new media library items, skips duplicates deterministically, and reports any failures through an import result contract

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

### Requirement: Media library state SHALL be consumable by video detail runtime
Media library continue-watching and provider-binding contracts SHALL be consumable by the video detail runtime without requiring media scanning, catalog import, storage implementation details, provider runtime internals, gateway requests, network resources, or UI state.

#### Scenario: Detail runtime reads continue-watching state
- **WHEN** a detail id resolves to local media with playback history
- **THEN** the detail runtime can include continue-watching state from media-library contracts without owning history persistence or playback progress recording

### Requirement: User-confirmed bindings SHALL drive video detail follow state
User-confirmed provider bindings SHALL drive video detail follow state and SHALL outrank automatic bindings when the detail runtime derives follow/unfollow actions.

#### Scenario: Detail binding is user-confirmed
- **WHEN** a local media item has a user-confirmed provider binding for the selected metadata provider
- **THEN** the detail runtime exposes a followed state and does not replace it with lower-confidence automatic metadata matches

