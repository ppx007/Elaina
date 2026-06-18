## ADDED Requirements

### Requirement: Concrete libtorrent adapter SHALL expose scheduler plan application
The concrete libtorrent Streaming adapter SHALL provide a
`PiecePriorityPlanApplier` implementation that applies scheduler plans through
the adapter/backend boundary and reports only normalized scheduler application
outcomes.

#### Scenario: Libtorrent applier accepts a plan
- **WHEN** a generated scheduler plan targets a libtorrent task and backing
  file
- **THEN** the concrete applier delegates to the libtorrent backend's available
  priority API for that file and returns an accepted
  `PiecePriorityApplicationOutcome`

#### Scenario: Libtorrent applier rejects a plan
- **WHEN** the libtorrent backend rejects the priority application
- **THEN** the concrete applier returns an adapter-rejected scheduler outcome
  without leaking backend exception types

### Requirement: Concrete libtorrent priority application SHALL remain adapter-owned
The concrete libtorrent priority applier SHALL live in the approved Streaming
adapter surface and MUST NOT require UI, playback rendering, timeline overlay,
HTTP/range server, socket, pipe, WebView, diagnostics, RSS automation, or
network policy dependencies.

#### Scenario: Concrete applier is scanned
- **WHEN** boundary validation scans Step 54 implementation files
- **THEN** concrete libtorrent package usage is accepted only in the approved
  Streaming adapter file and tests
