## MODIFIED Requirements

### Requirement: Layered architecture SHALL isolate concrete BT engine packages
Concrete BT engine packages SHALL be imported only by approved Streaming-layer
adapter implementation files and tests. UI, Domain, Playback, Provider,
Gateway, Storage, Network, diagnostics, and neutral Streaming contracts SHALL
consume BT behavior only through declared Celesteria contracts, including the
neutral BT task runtime composition contract.

#### Scenario: Concrete BT package import is scanned
- **WHEN** boundary validation scans Dart source files
- **THEN** `package:libtorrent_flutter/` imports are accepted only in the
  approved concrete BT adapter file and rejected everywhere else in `lib/src`
