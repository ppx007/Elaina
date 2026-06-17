## ADDED Requirements

### Requirement: Virtual media stream SHALL support adapter-backed byte ranges
The virtual media stream capability SHALL expose a neutral byte-source boundary
that can serve requested ranges as `VirtualByteRangeChunk` values while keeping
callers independent of file handles, servers, torrent handles, and native
engine details.

#### Scenario: Selected file range is served
- **WHEN** a virtual stream descriptor has a concrete `file:` content URI and
  a caller opens a valid byte range
- **THEN** the stream emits chunks covering the requested range, records the
  buffered range, and publishes range-buffered invalidation through existing
  virtual stream contracts

#### Scenario: Selected file is unavailable
- **WHEN** the byte source cannot read the selected file behind a virtual
  stream descriptor
- **THEN** the stream reports a typed `fileUnavailable` or `rangeUnavailable`
  failure and records a range-failed event without leaking file-system
  exceptions to callers

### Requirement: Virtual media stream SHALL keep server and scheduler concerns out of Step 53
The Step 53 byte-serving path SHALL NOT introduce HTTP/range servers, sockets,
pipe servers, platform channels, FFI, concrete torrent engine APIs,
piece-priority application, timeline overlay behavior, UI, playback rendering,
RSS automation, WebView, diagnostics, network policy, or storage migration.

#### Scenario: Byte serving boundary is scanned
- **WHEN** boundary validation scans the Step 53 byte-serving implementation
- **THEN** filesystem byte reads are accepted only in the approved concrete
  file byte source and tests, while neutral virtual stream runtime files remain
  free of concrete IO dependencies
