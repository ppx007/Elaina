## ADDED Requirements

### Requirement: Video detail playback actions SHALL use playback source handoff
Video detail continue-playback and episode-selection actions SHALL prepare playable local media through the existing playback source handoff contract rather than constructing playback sources in UI, provider, media-library, storage, gateway, network, or native-player code.

#### Scenario: Detail action prepares playback
- **WHEN** a video detail action selects an episode with an associated local media identity
- **THEN** the action handler uses playback source handoff to prepare an existing playback source value and reports normalized success or handoff failure

### Requirement: Video detail playback actions MUST preserve handoff isolation
Video detail playback actions MUST NOT require Bangumi, Dandanplay, RSS, subtitle provider, media scanner, storage implementation, network client, MPV, VLC, libmpv, media-kit, platform channel, diagnostics, BT engine, or online-rule runtime dependencies inside the playback source handoff path.

#### Scenario: Detail handoff imports are checked
- **WHEN** validation scans the detail runtime and playback handoff path
- **THEN** no forbidden provider implementation, UI widget, storage implementation, network, native player, BT engine, RSS, subtitle provider, or online-rule dependency is required to prepare local media playback
