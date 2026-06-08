## ADDED Requirements

### Requirement: MPV facade SHALL participate in player core runtime without binding leakage
The MPV adapter facade SHALL be usable by the Phase 1 player core runtime through `PlayerAdapter` and `MpvAdapterBinding` contracts without exposing MPV, libmpv, media-kit, platform channel, or native handle types outside the Playback layer.

#### Scenario: Runtime uses unsupported facade
- **WHEN** player core runtime is created without a native MPV binding
- **THEN** MPV facade commands return normalized unsupported results and no concrete MPV/libmpv/media-kit type crosses into Domain, UI, Foundation, Provider, Storage, Streaming, or Network layers

### Requirement: Bound MPV facade SHALL report runtime capabilities before commands execute
The MPV facade SHALL expose its source, transport, track, progress, and lifecycle capabilities to player core runtime before playback controller commands are treated as executable.

#### Scenario: Runtime receives playback command
- **WHEN** player core runtime handles a command through a bound MPV facade
- **THEN** the command is gated by the facade capability declaration before delegation to the binding
