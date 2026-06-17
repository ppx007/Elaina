## ADDED Requirements

### Requirement: Media library smoke gate SHALL validate the Phase C local library flow
The media-library runtime implementation SHALL provide a non-UI smoke gate that
executes the storage-backed local-library flow from local scan through
continue-watching replay.

#### Scenario: Library smoke gate runs
- **WHEN** the smoke gate creates a local media root, scans supported files,
  imports candidates, saves provider bindings, records playback history from a
  `PlaybackStateSnapshot`, loads storage-backed detail data, routes local
  playback handoff, reopens storage, and refreshes the library snapshot
- **THEN** it observes imported catalog items, deterministic detail episodes,
  a successful playback handoff, `HistoryRecorded` and `BindingChanged`
  invalidations, and persisted continue-watching state without requiring
  Flutter UI, concrete player bindings, provider HTTP transports, RSS, BT,
  streaming, network policy, diagnostics, SQLite SQL outside storage
  implementation, or app-shell code
