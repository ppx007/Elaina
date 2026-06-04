# playback-source-handoff-contract Specification

## Purpose
Define the deterministic local-media handoff that prepares selected media values into playback sources without introducing provider, storage, streaming, network, or native player dependencies.

## Requirements
### Requirement: Playback source handoff SHALL prepare local media into playback sources
The playback source handoff contract SHALL convert selected local media identities or scan candidates into `PlaybackSource` values that can be opened by the playback controller.

#### Scenario: Local media identity is prepared
- **WHEN** a selected local media identity has a file URI
- **THEN** the handoff returns a local file playback source without requiring provider metadata, storage-backed library state, gateway traffic, streaming engines, network clients, or native player bindings

### Requirement: Playback source handoff SHALL report unsupported inputs explicitly
The playback source handoff contract SHALL return an explicit failure result for unsupported URI schemes, missing source data, or selections that cannot be represented as a playback source.

#### Scenario: Unsupported source scheme is prepared
- **WHEN** a selected media identity uses a URI scheme outside the handoff's supported source categories
- **THEN** the handoff returns a normalized failure result instead of throwing a concrete platform, provider, storage, streaming, gateway, network, or native player exception

### Requirement: Playback source handoff SHALL reuse existing PlaybackSource contracts
The playback source handoff contract SHALL produce existing `PlaybackSource` values rather than defining parallel UI-local, media-library-local, provider-local, or adapter-local playback source models.

#### Scenario: Controller opens prepared source
- **WHEN** the playback controller receives a source produced by the handoff contract
- **THEN** it opens the source through the existing controller and player adapter contracts

### Requirement: Playback source handoff MUST preserve layer isolation
The handoff contract MUST NOT require Provider, Gateway, Storage, Streaming, Network, MPV, VLC, libmpv, media-kit, platform channel, diagnostics, danmaku, Anime4K, RSS, Bangumi, Dandanplay, or online rule runtime dependencies.

#### Scenario: Handoff imports are checked
- **WHEN** automation scans the handoff contract and playback runtime checks
- **THEN** no dependency on provider implementations, gateway implementations, storage implementations, streaming implementations, network implementations, native player bindings, Flutter widgets, or later-phase ACG integrations is required

### Requirement: Playback source handoff SHALL remain deterministic
The first playback source handoff SHALL be deterministic and synchronous with respect to already-selected local media values, and MUST NOT perform filesystem scans, database lookups, provider lookups, network requests, or media probing.

#### Scenario: Handoff test runs offline
- **WHEN** handoff tests prepare a local media identity or scan candidate
- **THEN** validation completes without filesystem traversal, database access, provider calls, gateway calls, network calls, or native playback startup
