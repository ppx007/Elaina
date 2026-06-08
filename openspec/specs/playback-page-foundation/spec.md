# playback-page-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-player-core. Update Purpose after archive.
## Requirements
### Requirement: Playback page SHALL stay capability-driven
The playback page SHALL be a thin UI surface that renders video surface state, basic controls, progress state, and secondary panel entry points from Domain/Playback contracts and the capability matrix.

#### Scenario: Playback page initializes
- **WHEN** the playback page opens for a supported source
- **THEN** it renders only controls and entry points allowed by the current capability matrix

### Requirement: Playback page MUST NOT include later-phase integrations
The playback page foundation MUST NOT require provider metadata, danmaku, advanced subtitle rendering, BT streaming, video enhancement, online source parsing, or diagnostics center integration.

#### Scenario: Local file playback is available
- **WHEN** a local file can be played through the active adapter
- **THEN** playback can proceed without Bangumi, Dandanplay, RSS, BT, Anime4K, rule-source, or diagnostics dependencies

### Requirement: Advanced actions SHALL be secondary panel entry points only
The playback page SHALL reserve secondary panel entry points for later advanced actions without implementing those actions in this change.

#### Scenario: Advanced feature is not implemented yet
- **WHEN** a later-phase feature such as danmaku or enhancement is not available
- **THEN** the playback page does not expose it as an active control

### Requirement: Playback page foundation SHALL be verifiable without UI-native imports
The playback page foundation SHALL be validated through Domain and Playback surface state contracts without importing concrete MPV, VLC, native player, provider, streaming, or advanced playback implementations.

#### Scenario: Domain surface state is resolved
- **WHEN** a playback surface consumer asks the Domain playback controller for visible controls and available panels
- **THEN** the returned state is derived from Playback contracts and capability matrix data only

### Requirement: Core playback runtime slice MUST remain independent of later-phase systems
The Player core runtime slice MUST NOT require provider metadata, danmaku rendering, advanced subtitle rendering, BT streaming, video enhancement, online rule parsing, VLC fallback, or diagnostics integration.

#### Scenario: Local adapter path is verified
- **WHEN** the Player core runtime slice is validated with a bound in-memory adapter
- **THEN** validation completes without importing Bangumi, Dandanplay, RSS, BT streaming, Anime4K, VLC fallback, online rule runtime, or diagnostics center code

### Requirement: Playback page foundation SHALL consume UI surface descriptors
The playback page foundation SHALL consume a UI-owned playback page surface contract that maps Domain playback surface state into renderable control and panel descriptors.

#### Scenario: Playback page foundation consumes surface model
- **WHEN** playback page foundation logic needs controls or panels
- **THEN** it consumes UI surface descriptors instead of importing concrete MPV, native player, provider, streaming, or Playback implementation details directly

### Requirement: Domain and Playback MUST NOT import playback page surface contracts
Domain and Playback layers MUST NOT import UI playback page surface contract types or presentation descriptors.

#### Scenario: Layer dependency is checked
- **WHEN** automation scans Domain and Playback Dart files
- **THEN** no import points from those layers into `lib/src/ui` are present

### Requirement: Playback page foundation SHALL consume player core runtime surfaces indirectly
The playback page foundation SHALL consume controller surface state, playback state snapshots, capability matrix data, and intent results produced by player core runtime through Domain/UI contracts rather than importing concrete adapter or binding implementations.

#### Scenario: Playback page asks for visible controls
- **WHEN** playback page foundation resolves visible controls and panels
- **THEN** the result is derived from player core runtime capabilities and controller surface state without importing MPV, libmpv, media-kit, native player, Provider, Streaming, Storage, Network, or playback binding implementation details

### Requirement: Playback page foundation MUST remain render-surface optional in Phase 1 runtime
The Phase 1 player core runtime bootstrap MUST NOT require Flutter video rendering, `MaterialApp`, navigation, platform views, or native video surfaces to validate playback page foundation contracts.

#### Scenario: Runtime tests execute without UI shell
- **WHEN** Phase 1 player core runtime tests run
- **THEN** playback page foundation behavior is verified through descriptors and intent results rather than mounted Flutter widgets or native video surfaces

