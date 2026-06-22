## MODIFIED Requirements

### Requirement: Media Library UI SHALL display scanned folder list
The media library page SHALL display configured local folders, folder-level
indexed counts, scanner state, and folder edit/remove controls backed by
`SettingsPreferenceKeys.mediaLibraryRoots` and `MediaLibraryRuntime`
projections.

#### Scenario: Render libraries list
- **WHEN** the media library page is loaded
- **THEN** the UI displays configured directory paths, indexed counts, and
  scanner status details
- **AND** the user can add, replace, or remove configured folders without
  changing indexed local files directly

### Requirement: Media Library UI SHALL show scan progress and scanner trigger
The media library page SHALL provide a scanner toolbar action, summary metrics,
scan progress, scan failures, and import outcomes using existing
`MediaLibraryRuntime` scan and import actions.

#### Scenario: Trigger scanner
- **WHEN** the user activates the scan library command button
- **THEN** the UI dispatches a scan using the configured folder roots and
  supported video extensions
- **AND** imports accepted candidates through `MediaLibraryRuntime`
- **AND** displays progress, duplicate skips, import failures, and empty results
  without invoking storage, scanner, or playback internals from UI

## ADDED Requirements

### Requirement: Media Library UI SHALL provide catalog management workspace
The media library page SHALL render a dense desktop workspace with toolbar,
summary metrics, folder pane, searchable media list, and selected media detail
panel.

#### Scenario: Render catalog workspace
- **WHEN** catalog items are available
- **THEN** the page displays media filename, path, duration, continue-watching
  progress, Bangumi binding state, and row actions from the runtime snapshot
- **AND** the selected media detail panel provides playback, Bangumi matching,
  detail navigation, and index removal commands

### Requirement: Media Library UI SHALL filter and sort catalog items
The media library page SHALL support text search and filters for all,
continue-watching, Bangumi-bound, and unbound media.

#### Scenario: Filter indexed media
- **WHEN** the user enters a search query or changes the media filter
- **THEN** only matching runtime catalog items are displayed
- **AND** items are ordered by continue-watching update time, added time, and
  filename to keep active media first

### Requirement: Media Library UI SHALL preserve runtime boundaries for actions
The media library page SHALL route local playback, one-off file playback,
Bangumi matching, detail navigation, and index removal through existing domain
runtime contracts.

#### Scenario: Open one local file
- **WHEN** the user chooses a single media file outside the catalog
- **THEN** the UI creates a `MediaScanCandidate` value and delegates playback
  preparation to `MediaLibraryRuntime.playCandidate`
- **AND** the UI does not instantiate playback handoff implementations directly

#### Scenario: Remove indexed item
- **WHEN** the user removes a catalog item
- **THEN** the page asks for confirmation and removes only the catalog index
  record through `MediaLibraryRuntime.remove`
- **AND** the UI communicates that the local media file is preserved
