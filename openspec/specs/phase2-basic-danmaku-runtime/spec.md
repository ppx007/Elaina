# phase2-basic-danmaku-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase2-basic-danmaku-runtime. Update Purpose after archive.
## Requirements
### Requirement: Basic danmaku runtime SHALL resolve frames from player-clock snapshots
The Phase 2 basic danmaku runtime SHALL resolve deterministic render frames for scrolling, top, and bottom comments using `PlayerClockSnapshot` as the only timing source and without concrete Flutter widgets, native renderer handles, Matrix4 effects, ProviderGateway access, Dandanplay transport, RSS, BT, online-rule, storage migration, network policy, or diagnostics dependencies.

#### Scenario: Runtime resolves an active frame
- **WHEN** the runtime receives comments and a player-clock snapshot at an eligible timestamp
- **THEN** it returns a deterministic danmaku frame grouped into scrolling, top, and bottom lanes without reading wall-clock time

### Requirement: Basic danmaku runtime SHALL apply filtering and density deterministically
The basic danmaku runtime SHALL apply `DanmakuFilter` before `DanmakuDensityPolicy`, preserve deterministic ordering, and expose only density-allowed comments in frame lanes.

#### Scenario: Filter and density limit are applied
- **WHEN** a frame contains blocked keywords, hidden modes, and more eligible comments than the density policy allows
- **THEN** blocked or hidden comments are removed first and only the configured number of remaining comments is exposed

### Requirement: Basic danmaku runtime SHALL preserve lifecycle-safe snapshots
The basic danmaku runtime SHALL expose immutable or defensively copied snapshots for loaded comments, active frame state, failure state, and disposed state.

#### Scenario: Runtime is disposed
- **WHEN** frame resolution or comment loading is requested after disposal
- **THEN** the runtime returns a normalized disposed or unavailable state without mutating existing snapshots

### Requirement: Basic danmaku runtime SHALL normalize Dandanplay comments without provider coupling
The runtime slice SHALL provide a bridge that converts Dandanplay comment mode, timestamp, text, and color data into Playback-layer `DanmakuComment` values without making Playback danmaku code import provider runtime, gateway, network, or account-session implementations.

#### Scenario: Dandanplay comments are projected to danmaku comments
- **WHEN** Domain receives Dandanplay comments for a matched episode
- **THEN** bridge helpers can produce player-clock-aligned `DanmakuComment` values for the basic renderer while provider failures remain outside the render path

### Requirement: Basic danmaku runtime SHALL accept provider comments through a bridge
The basic danmaku runtime SHALL remain provider-client-neutral while allowing a
Domain playback metadata bridge to load normalized Dandanplay comments through
existing `DanmakuComment` conversion.

#### Scenario: Dandanplay comments are prepared for playback
- **WHEN** the metadata bridge receives Dandanplay comment provider results for
  an episode
- **THEN** it converts those comments to Playback-layer `DanmakuComment`
  values, loads `BasicDanmakuRuntime`, and resolves a clock-driven danmaku
  projection without importing concrete Dandanplay API clients into Playback
  rendering code

