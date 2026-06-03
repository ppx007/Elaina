## ADDED Requirements

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
