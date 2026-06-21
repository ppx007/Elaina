## MODIFIED Requirements

### Requirement: Downloads Page SHALL render active torrent downloads
The downloads page SHALL display a dense BT management workspace backed by
`DownloadRuntime`, including task state, progress, download speed, upload speed,
peer count, total size, source kind, info hash, latest message or event, and
file selection state.

#### Scenario: Render download management workspace
- **WHEN** the downloads page is opened
- **THEN** it renders a toolbar, status summary, task list, search or filter
  controls, and a detail panel from `DownloadRuntime` projections
- **AND** the UI does not import concrete torrent engine APIs

#### Scenario: Render task file details
- **WHEN** a task with metadata is selected
- **THEN** the detail panel shows file path, size, index, media type, and
  selected/skipped state for each file

### Requirement: Downloads Page SHALL support torrent task control operations
The downloads page SHALL provide controls to add, pause, resume, batch
pause/resume, select files, and remove BT download tasks while respecting
runtime capabilities.

#### Scenario: Quick add magnet or local torrent
- **WHEN** the user quick-adds a magnet URI or local torrent file URI
- **THEN** the page creates a BT task, fetches metadata when available, selects
  all files by default, and refreshes the task list

#### Scenario: Advanced add selects files
- **WHEN** the user advanced-adds a supported source and metadata includes files
- **THEN** the page shows file choices before resuming the task
- **AND** confirmation is disabled while no file is selected

#### Scenario: Unsupported HTTP source
- **WHEN** the user submits an HTTP(S) torrent URL
- **THEN** the page shows a clear unsupported-source error instead of creating a
  fake task

#### Scenario: Remove task requires confirmation
- **WHEN** the user requests task removal
- **THEN** the page asks for confirmation and only removes the engine task
  record after confirmation
