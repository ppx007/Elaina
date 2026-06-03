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

