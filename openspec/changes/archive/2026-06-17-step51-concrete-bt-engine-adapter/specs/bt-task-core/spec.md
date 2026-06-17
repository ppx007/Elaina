## ADDED Requirements

### Requirement: BT task core SHALL provide a concrete libtorrent adapter
The BT task core SHALL provide a concrete Streaming-layer implementation of
`DownloadEngineAdapter` backed by a libtorrent integration package while
preserving the existing engine-neutral task contracts.

#### Scenario: Concrete adapter creates a magnet task
- **WHEN** a caller injects the concrete adapter into `BtTaskCoreRuntime` and
  creates a magnet task
- **THEN** the adapter delegates to the libtorrent backend and returns only a
  `BtTaskId`, not a concrete torrent handle or libtorrent object

#### Scenario: Concrete adapter maps metadata
- **WHEN** metadata is available from the libtorrent backend
- **THEN** the adapter maps torrent name, total size, piece length, info hash,
  and file list into `BtTaskMetadata` and `BtTaskFile` values

### Requirement: Concrete BT adapter SHALL keep later streaming features out of Step 51
The concrete BT adapter SHALL NOT expose virtual byte serving, HTTP/range
servers, pipe servers, playback sources, piece priority application, timeline
overlay data, RSS automation, diagnostics, WebView, or UI behavior.

#### Scenario: Step 51 adapter is used by task runtime
- **WHEN** the adapter is used by `BtTaskCoreRuntime`
- **THEN** it supports task lifecycle and metadata/file selection through
  `DownloadEngineAdapter` only, leaving virtual streams and byte serving to
  later steps
