## Why

The controller and shell can now exercise a mock playback loop, but the project still lacks a small contract for handing selected local media into the playback source model. This change closes the next Phase 1 gap without introducing provider metadata, storage persistence, network fetching, streaming, or native player bindings.

## What Changes

- Add a playback source handoff contract that converts local media identities or scan candidates into `PlaybackSource` values accepted by the controller and player adapter contracts.
- Keep the handoff local-media-first and deterministic, covering local file playback only unless an existing `PlaybackSource` is already available.
- Preserve layer boundaries: UI chooses media through Domain contracts, Domain prepares a playback handoff, and Playback receives normalized source values without importing media library internals.
- Add validation that the handoff does not require Provider, Gateway, Storage, Streaming, Network, MPV/native bindings, online source parsing, Bangumi, Dandanplay, RSS, BT, diagnostics, danmaku, Anime4K, or production app routing.

## Capabilities

### New Capabilities
- `playback-source-handoff-contract`: Contract for preparing local media selections into playback sources that the controller can open without provider, storage, streaming, or network dependencies.

### Modified Capabilities
- `media-library-foundation`: Local media identity and scan candidates must be usable as source-handoff inputs without requiring provider metadata or storage-backed library state.
- `mpv-adapter-boundary`: Player source contracts must remain the only values handed to playback adapters after local media preparation.

## Impact

- Affects Domain media and Domain playback contracts that connect selected local media to playback source creation.
- Affects controller/runtime tests so local media handoff can be validated before native playback or provider metadata exists.
- Does not add scanning implementation, database persistence, ProviderGateway traffic, online source parsing, native MPV bindings, platform channels, BT streaming, or UI visual work.
