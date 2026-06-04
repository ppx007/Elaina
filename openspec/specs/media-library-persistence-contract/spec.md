# media-library-persistence-contract Specification

## Purpose
Defines persistent catalog, scan import, playback history, and provider binding repository contracts for the media library domain.

## Requirements
### Requirement: Media library SHALL persist catalog items
The system SHALL define a repository contract for storing, retrieving, updating, listing, and removing media library items independently of provider metadata or UI state.

#### Scenario: A catalog item is stored
- **WHEN** a media library item is added to the persistent catalog
- **THEN** it can later be loaded, updated, listed, and removed through the media library repository contract

### Requirement: Scan results SHALL be importable into the media library
The system SHALL define a batch import contract that converts local media scan candidates into persisted catalog items with deterministic deduplication and failure reporting.

#### Scenario: A scan returns duplicate candidates
- **WHEN** a batch import processes candidates that match an existing item by URI or fingerprint
- **THEN** the import contract reports the duplicate as skipped rather than creating a second catalog item

### Requirement: Playback history SHALL be stored through a repository contract
The system SHALL define a storage-backed playback history contract that records playback progress and can derive continue-watching state from persisted entries.

#### Scenario: Playback progress is persisted
- **WHEN** playback progress is recorded for a media item
- **THEN** the history repository can later return the latest entry and a continue-watching summary for that item

### Requirement: Provider binding state SHALL be stored through a repository contract
The system SHALL define a storage-backed provider binding contract that preserves user-confirmed and automatic bindings for local media items.

#### Scenario: A user-confirmed binding is saved
- **WHEN** a binding is saved with user-confirmed authority
- **THEN** the repository preserves it as the authoritative binding for the media item unless a stronger user-confirmed binding replaces it
