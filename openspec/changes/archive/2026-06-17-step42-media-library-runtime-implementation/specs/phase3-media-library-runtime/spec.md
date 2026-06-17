## ADDED Requirements

### Requirement: Media library runtime SHALL provide concrete local-file scanning
The media-library runtime implementation SHALL provide a concrete local-file
scanner that traverses file-system directories, filters by normalized media
scan scope, emits existing scan events, and returns existing
`MediaScanCandidate` values without requiring UI file picker code.

#### Scenario: Local directory is scanned
- **WHEN** a file-backed scan scope points at a directory containing supported
  media files
- **THEN** the scanner returns accepted candidates with file URIs, basenames,
  sizes, optional duration metadata, and discovered timestamps using existing
  Domain media contracts

### Requirement: Media library runtime SHALL compose storage-backed repositories
The media-library runtime SHALL provide a composition path that adapts
`StorageFoundation` media catalog, playback history, and provider binding
contracts into the existing Domain media runtime repositories.

#### Scenario: Runtime is created with concrete storage
- **WHEN** an app composition root provides a `StorageFoundation`,
  `MediaLibraryScanner`, `PlaybackSourceHandoffContract`, and
  `CacheInvalidationBus`
- **THEN** the media-library runtime can scan, import, refresh catalog state,
  record playback history, save provider bindings, and route local playback
  without importing SQLite packages, SQL statements, UI widgets, provider
  clients, streaming engines, network clients, or native player bindings

### Requirement: Storage-backed media library runtime SHALL replay state after restart
The storage-backed media-library runtime SHALL rebuild catalog, continue
watching, and binding projections from storage after a runtime restart.

#### Scenario: Runtime restarts after import and history updates
- **WHEN** media items, playback history, and provider bindings were persisted
  through the storage-backed runtime
- **THEN** a later runtime composed with the same storage database can refresh
  and expose the imported catalog items, continue-watching entries, strongest
  provider bindings, and playback handoff support

### Requirement: Concrete media library implementation SHALL preserve UI ownership boundaries
Concrete media-library runtime implementation work SHALL provide core runtime
composition, tests, checkers, and integration notes without adding or
modifying Flutter app shell, media-library pages, routes, file picker UX,
thumbnail widgets, playback pages, Windows runner files, or UI state
composition.

#### Scenario: Step 42 is implemented
- **WHEN** Step 42 adds concrete scanner and storage-backed runtime composition
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain media contracts and composition
  notes rather than concrete SQLite, SQL, scanner internals, or storage row
  models

