## ADDED Requirements

### Requirement: Layered architecture SHALL isolate concrete piece-priority appliers
Concrete piece-priority plan appliers SHALL be implemented only inside
approved Streaming-layer adapter implementation files and tests. UI, Domain,
Playback, Provider, Gateway, Storage, Network, diagnostics, and neutral
Streaming scheduler runtime contracts SHALL consume priority application only
through `PiecePriorityPlanApplier` and normalized scheduler outcomes.

#### Scenario: Concrete priority applier import is scanned
- **WHEN** boundary validation scans Dart source files
- **THEN** concrete torrent package imports and backend priority APIs are
  accepted only in approved Streaming adapter implementation files and tests,
  while neutral scheduler runtime files remain adapter-neutral
