## ADDED Requirements

### Requirement: Video detail runtime SHALL participate in the library smoke gate
The storage-backed video-detail runtime SHALL be consumable by the non-UI
library smoke gate using persisted media-library catalog, playback-history, and
provider-binding state.

#### Scenario: Smoke gate loads storage-backed detail
- **WHEN** the library smoke gate binds imported local media to a deterministic
  metadata subject and loads detail data for that subject
- **THEN** the video-detail runtime returns local-media backed episodes,
  strongest binding state, latest continue-watching state, and contract-routed
  playback actions without importing UI widgets, concrete provider transports,
  native player bindings, RSS, BT, streaming, network, or diagnostics
  implementations
