## ADDED Requirements

### Requirement: Player adapter SHALL gate source loading by declared capabilities
The active `PlayerAdapter` SHALL return a normalized playback failure when asked to load a source category that is not supported by its current capability matrix.

#### Scenario: HLS source is unsupported
- **WHEN** the active adapter receives an `HlsPlaybackSource` while `hlsPlayback` is unsupported
- **THEN** the load operation returns a `PlaybackCommandResult.failure` with a normalized unsupported or adapter-unavailable failure instead of delegating to a concrete engine blindly

### Requirement: Bound MPV facade SHALL delegate only after binding availability is established
The MPV facade SHALL continue to report all executable playback capabilities as unsupported without a binding, and SHALL delegate load, transport, lifecycle, and track operations only when constructed with a concrete binding.

#### Scenario: Unsupported MPV facade receives playback command
- **WHEN** an unsupported MPV facade receives load, play, pause, seek, stop, dispose, track discovery, or track switching commands
- **THEN** each command returns an explicit normalized unsupported result without throwing a concrete MPV or native binding exception

#### Scenario: Bound MPV facade receives playback command
- **WHEN** a bound MPV facade receives load, play, pause, seek, stop, dispose, track discovery, or track switching commands
- **THEN** the facade delegates through the `MpvAdapterBinding` interface without exposing MPV/libmpv/media-kit types outside the Playback layer
