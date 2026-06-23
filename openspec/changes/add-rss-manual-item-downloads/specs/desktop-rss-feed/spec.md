## ADDED Requirements

### Requirement: RSS Page SHALL support manual item downloads
The RSS page SHALL allow users to enqueue individual downloadable feed items
and batch enqueue selected visible downloadable items through the RSS runtime.

#### Scenario: Download one feed item
- **WHEN** a feed item exposes a magnet link or supported torrent source
- **THEN** the item row shows a manual download action
- **AND** selecting the action asks `RssEngineRuntime` to enqueue that item
- **AND** the UI does not call `DownloadRuntime`, BT engines, storage, or
  concrete torrent resolvers directly

#### Scenario: Select visible downloadable items
- **WHEN** the user filters or searches the feed item list
- **AND** chooses to select visible downloadable resources
- **THEN** the page selects only currently visible items with a recognized RSS
  download source
- **AND** hidden items and non-downloadable items remain unselected

#### Scenario: Batch download selection
- **WHEN** one or more selected items are downloaded
- **THEN** the page calls the RSS runtime batch enqueue API
- **AND** it reports accepted and failed counts to the user
- **AND** the download-selected action is disabled while nothing is selected

#### Scenario: Non-download item controls
- **WHEN** a feed item has no recognized magnet or torrent source
- **THEN** the row does not expose a download checkbox or per-item download
  action
