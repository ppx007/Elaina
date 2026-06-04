## ADDED Requirements

### Requirement: Player adapters SHALL receive normalized playback sources after handoff
Player adapters SHALL receive only normalized `PlaybackSource` values after Domain media selection has been prepared by the playback source handoff contract.

#### Scenario: Adapter receives local media selection
- **WHEN** a local media selection is prepared for playback
- **THEN** the active player adapter receives a local file playback source rather than media library identity, scan candidate, provider metadata, UI selection state, storage records, or concrete platform file handles
