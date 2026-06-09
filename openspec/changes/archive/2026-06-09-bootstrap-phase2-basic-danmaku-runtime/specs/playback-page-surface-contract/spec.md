## MODIFIED Requirements

### Requirement: Later-phase systems MUST remain outside the surface contract
The playback page surface contract MUST NOT require provider metadata, advanced subtitle rendering, BT streaming, video enhancement, online rule parsing, VLC fallback, diagnostics integration, or native playback bindings. The surface contract MAY expose framework-neutral basic danmaku overlay descriptors once Phase 2 basic danmaku runtime is implemented, but it MUST NOT require concrete Flutter widgets, provider implementations, ProviderGateway, storage, network, Matrix4 effects, native renderer handles, MPV, libmpv, media-kit, or VLC code.

#### Scenario: Surface contract is validated
- **WHEN** the playback page surface contract is checked by automation
- **THEN** validation completes without importing or requiring Bangumi, Dandanplay provider implementations, RSS, BT streaming, Anime4K, VLC fallback, online rule runtime, diagnostics center, ProviderGateway, storage, network, MPV, libmpv, media-kit, concrete renderer widgets, or native player code

## ADDED Requirements

### Requirement: Playback page surface SHALL expose basic danmaku overlay descriptors
The playback page surface contract SHALL expose plain Dart descriptors for basic danmaku overlay lanes and comments so future UI can render danmaku without changing Domain or Playback runtime contracts.

#### Scenario: Surface descriptor maps danmaku state
- **WHEN** Domain playback state contains a basic danmaku overlay snapshot
- **THEN** the playback page surface descriptor exposes framework-neutral scrolling, top, and bottom lane data without importing Playback renderer implementations or Flutter rendering primitives
