## Why

The Player core baseline currently defines contracts, but it does not yet prove that controller commands, capability-driven UI state, adapter failure normalization, source gating, and track routing work together as an executable slice. This change turns the Phase 1 Player core contracts into a locally verifiable runtime path without introducing native MPV bindings or later-phase provider, subtitle, danmaku, BT, enhancement, or diagnostics integrations.

## What Changes

- Add a testable Player core runtime slice that exercises `PlaybackController` through a bound in-memory adapter implementation.
- Tighten source support checks so local file, HTTP, and HLS playback requests are accepted only when declared by the active adapter capability matrix.
- Verify unsupported MPV facade behavior remains explicit when no concrete binding is present.
- Verify capability-driven surface state exposes only controls and panels supported by the active adapter.
- Verify audio/subtitle track discovery and switching flow through normalized Playback contracts.
- No native MPV/libmpv/media-kit binding, Flutter playback UI, provider metadata, danmaku, BT streaming, Anime4K, VLC fallback, online rules, or diagnostics integration is added in this change.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `mpv-adapter-boundary`: Require source gating and normalized failure behavior to be covered by a locally executable adapter slice.
- `playback-capability-matrix`: Require controller-visible surface state to be derived from the active adapter matrix in executable checks.
- `playback-page-foundation`: Require the playback surface foundation contract to be validated through Domain/Playback state rather than UI/native imports.
- `track-management`: Require track discovery and switching to be verified through normalized descriptors and explicit unsupported states.

## Impact

- Affected code: `lib/src/domain/playback/`, `lib/src/playback/`, and project checker scripts under `tools/`.
- Affected specs: `mpv-adapter-boundary`, `playback-capability-matrix`, `playback-page-foundation`, and `track-management`.
- Dependencies: no new runtime dependency is expected; Dart-only tests or checker entry points should remain sufficient.
- Boundaries: UI must remain free of concrete MPV/VLC/native imports, and online/provider/streaming/advanced playback systems remain outside this slice.
