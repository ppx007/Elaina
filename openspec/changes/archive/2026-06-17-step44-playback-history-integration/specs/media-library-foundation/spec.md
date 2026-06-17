## ADDED Requirements

### Requirement: Playback history SHALL be recordable from playback state
The media-library foundation SHALL expose a Domain-owned path for turning
playback state snapshots into persisted playback history entries.

#### Scenario: Playback state is persisted
- **WHEN** playback state identifies a local media item through its source URI
  and has a timeline duration
- **THEN** media-library history contracts can persist the position, duration,
  and timestamp so continue-watching projections survive restart

### Requirement: Playback state history recording SHALL remain media-library owned
Playback state history recording SHALL resolve media identity through
media-library catalog contracts and SHALL NOT require UI code to construct
history ids, storage records, SQL, provider metadata, native player handles, or
concrete playback package values.

#### Scenario: UI consumes playback history integration
- **WHEN** app UI or an app shell wants continue-watching updates during
  playback
- **THEN** it attaches the Domain media observer/recorder through composition
  root contracts rather than importing storage internals, concrete player
  packages, provider clients, network clients, BT engines, or diagnostics
  implementations
