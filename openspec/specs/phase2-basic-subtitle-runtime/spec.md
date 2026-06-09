# phase2-basic-subtitle-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase2-basic-subtitle-runtime. Update Purpose after archive.
## Requirements
### Requirement: Phase 2 subtitle runtime SHALL compose deterministic subtitle services
The Phase 2 basic subtitle runtime SHALL compose parser registry, local subtitle discovery, track loading, offset handling, active-cue lookup, and lifecycle-safe subtitle state without requiring Flutter UI, provider systems, storage implementations, streaming engines, network clients, diagnostics center, or native player bindings.

#### Scenario: Runtime is constructed offline
- **WHEN** the basic subtitle runtime is constructed with deterministic parsers and scanner inputs
- **THEN** it can load and inspect subtitle state without importing MPV, VLC, libmpv, media-kit, platform channels, Provider, Gateway, Storage, Streaming, Network, diagnostics, or Flutter widget code

### Requirement: Subtitle runtime SHALL load parser-backed tracks
The subtitle runtime SHALL load external subtitle sources by selecting the registered parser for the source format and returning normalized subtitle tracks, warnings, or explicit unsupported-format failures.

#### Scenario: Supported subtitle source is loaded
- **WHEN** an SRT, WebVTT, or basic ASS subtitle source is loaded with parser-compatible content
- **THEN** the runtime returns a normalized subtitle track with cue timing and text data from the selected parser

#### Scenario: Unsupported subtitle source is loaded
- **WHEN** a subtitle source uses a format with no registered parser
- **THEN** the runtime returns an explicit unsupported-format result without throwing a native, provider, storage, streaming, or UI exception

### Requirement: Subtitle runtime SHALL expose active cues from player-clock snapshots
The subtitle runtime SHALL resolve active cues using player-clock position plus the configured subtitle offset rather than wall-clock time.

#### Scenario: Offset cue lookup is requested
- **WHEN** the player-clock snapshot position plus subtitle offset falls inside a cue interval
- **THEN** the runtime exposes that cue as active for the selected subtitle track

### Requirement: Subtitle runtime SHALL preserve immutable subtitle state snapshots
The subtitle runtime SHALL expose loaded tracks, selected track identity, active cues, offset, warnings, and failure state through immutable or defensively copied runtime snapshots.

#### Scenario: Caller mutates returned cue collection
- **WHEN** a caller attempts to modify a returned active-cue collection or loaded-track collection
- **THEN** subsequent subtitle runtime state remains unchanged

### Requirement: Subtitle runtime SHALL normalize lifecycle results
The subtitle runtime SHALL return deterministic disposed, unsupported, loaded, selected, and failure outcomes for runtime operations.

#### Scenario: Runtime is disposed
- **WHEN** subtitle load, scan, select, offset, or active-cue operations are requested after disposal
- **THEN** the runtime returns a normalized disposed result without delegating to parser, scanner, provider, storage, streaming, network, native player, or UI code

