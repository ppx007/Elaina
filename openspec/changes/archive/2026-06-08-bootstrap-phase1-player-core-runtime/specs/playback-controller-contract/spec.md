## ADDED Requirements

### Requirement: Player core runtime SHALL wire real controller commands through capability gates
The player core runtime SHALL provide a playback controller that routes load, play, pause, seek, stop, and track intents through capability-gated Playback contracts rather than deterministic UI-local mocks.

#### Scenario: Unsupported play command is handled
- **WHEN** a play command is dispatched while the active adapter reports transport playback as unsupported
- **THEN** the controller returns a normalized unsupported command result without invoking native bindings or UI state directly

### Requirement: Controller lifecycle SHALL be owned by player core runtime
The playback controller exposed by player core runtime SHALL reject commands after the runtime has been disposed.

#### Scenario: Command is dispatched after disposal
- **WHEN** a controller command is sent after player core runtime disposal
- **THEN** the command fails deterministically without touching adapter, provider, storage, streaming, network, or UI resources
