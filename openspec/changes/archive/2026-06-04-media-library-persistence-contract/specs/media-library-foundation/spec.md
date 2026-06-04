## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Media library SHALL persist catalog items and batch imports
The system SHALL define repository contracts for storing, retrieving, listing, updating, and removing media library items, and for importing scan candidates into the catalog with deterministic deduplication and result reporting.

#### Scenario: A scan import creates catalog entries
- **WHEN** a batch of local media scan candidates is imported into the catalog
- **THEN** the repository creates new media library items, skips duplicates deterministically, and reports any failures through an import result contract
