## ADDED Requirements

### Requirement: Player core runtime SHALL derive capability matrix from active adapter
The player core runtime SHALL derive its playback capability matrix from the active player adapter or deterministic binding declaration rather than hard-coded UI or controller assumptions.

#### Scenario: Active adapter declares unsupported HLS playback
- **WHEN** the active adapter reports HLS playback as unsupported
- **THEN** the runtime capability matrix reports HLS playback as unsupported and controller/page surfaces do not expose HLS playback as executable

### Requirement: Capability matrix SHALL remain stable within runtime snapshots
The player core runtime SHALL expose a stable capability matrix snapshot for controller and page foundation consumers until the active adapter changes or the runtime is rebuilt.

#### Scenario: Controller resolves surface state
- **WHEN** the playback controller resolves visible controls and panels
- **THEN** it reads the runtime capability matrix snapshot rather than recalculating adapter-specific capability rules independently
