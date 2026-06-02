## ADDED Requirements

### Requirement: BT task core SHALL define engine-neutral task contracts
The system SHALL define BT task identity, source, metadata, file list, lifecycle state, and command contracts without exposing concrete download-engine APIs to UI or player layers.

#### Scenario: Magnet task is created
- **WHEN** Domain creates a BT task from a magnet or torrent source
- **THEN** the task is represented by engine-neutral contracts and routed through a download-engine adapter boundary

### Requirement: BT task file selection SHALL remain playback aware
The system SHALL expose task file descriptors and selected media files without requiring the player to inspect torrent engine internals.

#### Scenario: User selects a media file from a BT task
- **WHEN** a playable file is selected from a BT task file list
- **THEN** playback resolves it through virtual stream or playback source contracts rather than concrete torrent file handles

### Requirement: BT lifecycle SHALL be capability gated
The system SHALL define BT task lifecycle actions in a way that can be hidden or degraded when the platform does not support a capability such as long background downloading.

#### Scenario: Platform has limited background support
- **WHEN** the current platform cannot support long background BT work
- **THEN** Domain capability contracts expose the limitation rather than promising unsupported behavior
