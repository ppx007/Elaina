# Phase 5: Advanced Playback Core

This phase adds contract scaffolding for Celesteria architecture plan steps 22-25.

## Implemented Boundary

- Video enhancement contracts describe scaler, HDR, deband, and Anime4K-style profile intent with durable profile storage, typed evaluation/apply/disable outcomes, cache invalidation events, and render-budget pressure handoff without concrete MPV shader implementation.
- `AVSyncGuard` contracts define drift samples, health states, red-line degradation actions, and deterministic policy ordering.
- Advanced caption contracts define Matrix4 danmaku, dual subtitles, PGS rendering intent, and ASS enhancement intent without changing basic parser contracts.
- Fallback adapter contracts describe secondary adapter selection and hidden capability reporting without requiring VLC as a mandatory dependency.
- Playback capability rows expose advanced rendering and fallback gating to UI through the existing capability matrix.

## Non-Goals Preserved

- No concrete MPV shader graph, Anime4K shader bundle, VLC binding, native plugin, or platform renderer implementation.
- No diagnostics center, DNS/network policy, online source rule runtime, RSS auto-download, or WebView challenge handling.
- No change that makes advanced rendering or fallback adapters mandatory for the core playback loop.
- Step 22 exposes budget pressure and degradation targets as data only; AVSyncGuard remains responsible for drift policy in the next contract slice.

The next change should move into Phase 6 only after this change is implemented and archived.
