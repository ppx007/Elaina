## MODIFIED Requirements

### Requirement: Later-phase systems MUST remain outside playback state contract
The playback state contract MUST NOT require provider metadata, advanced subtitle rendering, BT streaming, video enhancement, online rule parsing, VLC fallback, diagnostics integration, Flutter widgets, or native playback bindings. The contract MAY expose framework-neutral basic danmaku overlay snapshot data once Phase 2 basic danmaku runtime is implemented, but it MUST NOT require provider implementations, concrete rendering widgets, Matrix4 effects, gateway, storage, network, or native-player dependencies.

#### Scenario: Playback state contract is validated
- **WHEN** the playback state contract is checked by automation
- **THEN** validation completes without importing or requiring Bangumi, Dandanplay provider implementations, RSS, BT streaming, Anime4K, VLC fallback, online rule runtime, diagnostics center, Flutter, MPV, libmpv, media-kit, gateway, storage, network, or native player code

## ADDED Requirements

### Requirement: Playback state SHALL expose basic danmaku overlay snapshots
Playback state contracts SHALL expose basic danmaku overlay data such as active frame lanes, clock position, filter state, density policy, and failure state using immutable framework-neutral value types.

#### Scenario: Danmaku state is observed
- **WHEN** a playback consumer observes state after basic danmaku comments are loaded and eligible for the current clock position
- **THEN** the snapshot exposes basic danmaku overlay data without Flutter widgets, BuildContext, provider clients, gateway clients, storage records, network responses, Matrix4 transforms, or native renderer handles
