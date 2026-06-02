# Next Change Boundary: Phase 1 Player Core

Start this change only after `bootstrap-phase-0-foundation` is implemented and archived.

## Scope

- Step 5: MPV Adapter boundary for local file, HTTP, and HLS playback.
- Step 6: Capability Matrix for player capability declaration.
- Step 7: Playback page foundation that renders only capabilities exposed by the matrix.
- Step 8: Audio and subtitle track discovery/switching contracts.

## Explicit Non-Goals

- Advanced subtitles, danmaku, Bangumi integration, Dandanplay integration, RSS, BT streaming, Anime4K, VLC fallback, online rule sources, and diagnostics center.
- UI direct imports of concrete MPV/VLC/native player implementations.

## Carry-Forward Checks

- Player work must depend on Phase 0 adapter and layer contracts.
- Provider traffic remains behind `ProviderGateway`.
- Cache invalidation remains event-driven through `CacheInvalidationBus`.
