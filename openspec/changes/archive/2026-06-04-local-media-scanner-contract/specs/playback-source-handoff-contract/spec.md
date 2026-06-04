## ADDED Requirements

### Requirement: Scanner-produced file candidates SHALL preserve playback handoff invariants
The playback source handoff contract SHALL accept scanner-produced `MediaScanCandidate` values only when they preserve the handoff invariants required for local file playback preparation: non-empty file URI, non-empty basename, non-negative size, and no scanner-owned `PlaybackSource` construction.

#### Scenario: Scanner candidate is prepared for playback
- **WHEN** a local media scanner produces a candidate whose identity has a non-empty file URI and valid local media fields
- **THEN** the playback source handoff can prepare that candidate into an existing local file playback source without provider metadata, storage-backed library state, gateway traffic, network clients, streaming engines, UI widgets, or native player bindings

#### Scenario: Scanner candidate is not handoff-safe
- **WHEN** a local media scanner produces or receives a candidate with missing source data or an unsupported URI scheme
- **THEN** the playback source handoff returns its existing explicit failure result rather than accepting scanner-local source assumptions or constructing a parallel playback source model
