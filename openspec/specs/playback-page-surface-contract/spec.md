# playback-page-surface-contract Specification

## Purpose
TBD - created by archiving change implement-playback-page-surface-contract. Update Purpose after archive.
## Requirements
### Requirement: Playback page surface contract SHALL be UI-owned
The playback page surface contract SHALL live in the UI layer and SHALL depend only on Domain-facing playback contracts, not concrete Playback, native-player, provider, streaming, gateway, storage, or network implementations.

#### Scenario: Surface contract maps Domain state
- **WHEN** the surface contract resolves playback controls and panels
- **THEN** it consumes `PlaybackSurfaceState` or equivalent Domain-facing playback state without importing MPV, VLC, libmpv, media-kit, provider internals, streaming internals, or native player bindings

### Requirement: Surface descriptors SHALL be framework-neutral
The playback page surface contract SHALL expose plain Dart descriptors for controls and panels rather than Flutter widgets, BuildContext values, themes, layout state, or native rendering handles.

#### Scenario: Playback page controls are rendered later
- **WHEN** a future Flutter widget consumes the surface contract
- **THEN** it receives stable descriptor data that can be rendered without changing Domain or Playback contracts

### Requirement: Unsupported capabilities MUST NOT become active controls
The playback page surface contract MUST hide or omit controls and panels whose capabilities are unsupported by the active playback surface state.

#### Scenario: Track switching is unsupported
- **WHEN** audio and subtitle track controls are absent from the Domain playback surface state
- **THEN** the UI surface descriptors do not expose audio or subtitle track controls as active controls

#### Scenario: Secondary panel is unsupported
- **WHEN** the tracks panel is absent from the Domain playback surface state
- **THEN** the UI surface descriptors do not expose the tracks panel as an active panel entry point

### Requirement: Later-phase systems MUST remain outside the surface contract
The playback page surface contract MUST NOT require provider metadata, advanced subtitle rendering, BT streaming, video enhancement, online rule parsing, VLC fallback, diagnostics integration, or native playback bindings. The surface contract MAY expose framework-neutral basic danmaku overlay descriptors once Phase 2 basic danmaku runtime is implemented, but it MUST NOT require concrete Flutter widgets, provider implementations, ProviderGateway, storage, network, Matrix4 effects, native renderer handles, MPV, libmpv, media-kit, or VLC code.

#### Scenario: Surface contract is validated
- **WHEN** the playback page surface contract is checked by automation
- **THEN** validation completes without importing or requiring Bangumi, Dandanplay provider implementations, RSS, BT streaming, Anime4K, VLC fallback, online rule runtime, diagnostics center, ProviderGateway, storage, network, MPV, libmpv, media-kit, concrete renderer widgets, or native player code

### Requirement: Playback page surface SHALL expose basic danmaku overlay descriptors
The playback page surface contract SHALL expose plain Dart descriptors for basic danmaku overlay lanes and comments so future UI can render danmaku without changing Domain or Playback runtime contracts.

#### Scenario: Surface descriptor maps danmaku state
- **WHEN** Domain playback state contains a basic danmaku overlay snapshot
- **THEN** the playback page surface descriptor exposes framework-neutral scrolling, top, and bottom lane data without importing Playback renderer implementations or Flutter rendering primitives

