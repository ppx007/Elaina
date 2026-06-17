## ADDED Requirements

### Requirement: Media library runtime SHALL integrate playback history from playback snapshots
The media-library runtime implementation SHALL provide a non-UI integration
surface that records playback progress from `PlaybackStateSnapshot` values into
the existing `PlaybackHistoryStore`.

#### Scenario: Playback snapshot records progress
- **WHEN** playback state contains a catalog-backed `sourceUri`, a timeline
  position, and a duration
- **THEN** the integration resolves the catalog item, writes a
  `PlaybackHistoryEntry`, publishes `HistoryRecorded`, and returns a typed
  success result without requiring UI widgets, concrete player bindings,
  SQLite packages, SQL statements, provider clients, RSS, BT, network policy,
  diagnostics, or native player callbacks

### Requirement: Playback history integration SHALL skip incomplete snapshots safely
Playback history integration SHALL return typed skipped outcomes for playback
snapshots that cannot produce durable history records.

#### Scenario: Snapshot lacks durable media context
- **WHEN** a playback snapshot has no source URI, no duration, a source URI not
  present in the media catalog, or a non-recordable playback lifecycle state
- **THEN** the integration returns a typed skipped outcome and does not write
  playback history or publish history invalidation events

### Requirement: Playback history observer SHALL be attachable by composition roots
The media-library runtime implementation SHALL provide a small observer wrapper
that app composition roots can attach to a playback state observable without
adding UI ownership or concrete player dependencies.

#### Scenario: Composition root attaches observer
- **WHEN** a `PlaybackControllerContract` publishes state snapshots during
  playback
- **THEN** the observer delegates recording to the playback history recorder
  and can be disposed so it stops observing future playback state
