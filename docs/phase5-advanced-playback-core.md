# Phase 5: Advanced Playback Core

This phase adds contract scaffolding for Elaina architecture plan steps 22-25.

## Implemented Boundary

- Video enhancement contracts describe scaler, HDR, deband, and Anime4K-style profile intent with durable profile storage, typed evaluation/apply/disable outcomes, cache invalidation events, and render-budget pressure handoff without concrete MPV shader implementation.
- `AVSyncGuard` contracts define durable sync policy/state, sustained drift sample windows, typed health/degradation outcomes, red-line degradation actions, recovery events, and deterministic policy ordering.
- Advanced caption contracts define Matrix4 danmaku, ordered dual subtitles, PGS rendering intent, and ASS enhancement intent with durable profile storage, typed evaluation/render/disable/degradation outcomes, feature capability reasons, cache invalidation events, and declarative `disableAdvancedCaptions` acceptance without changing basic parser contracts.
- Fallback adapter contracts describe durable secondary adapter registration, active fallback configuration, typed selection/disable/capability-reevaluation outcomes, selection history, hidden capability reporting, and invalidation events without requiring VLC as a mandatory dependency.
- Step 58 adds a Playback-owned `VlcFallbackAdapter` seam with an injected backend interface, local-file fallback capability declaration, typed unavailable/unsupported/disposed/operation-failed command results, and a fallback candidate factory. It does not add a verified native VLC package dependency or UI-owned fallback surface.
- Playback capability rows expose advanced rendering and fallback gating to UI through the existing capability matrix.

## Non-Goals Preserved

- No concrete MPV shader graph, Anime4K shader bundle, verified native VLC package dependency, native plugin, or platform renderer implementation.
- No diagnostics center, DNS/network policy, online source rule runtime, RSS auto-download, or WebView challenge handling.
- No change that makes advanced rendering or fallback adapters mandatory for the core playback loop.
- Step 25 fallback contracts persist declarative adapter ids, priorities, capability rows, active configuration, selection history, and strategy state only; they do not store native handles, concrete player instances, VLC objects, platform resources, media-kit bridges, FFI bindings, Flutter widgets, diagnostics integration, or provider/network automation.
- Step 22 exposes budget pressure and degradation targets as data only; Step 23 AVSyncGuard consumes that pressure as input data and emits degradation decisions without executing renderer mutations; Step 24 advanced captions consume `disableAdvancedCaptions` as declarative state only and do not own AV sync policy.
- Step 24 does not introduce Flutter widgets, Matrix4 layout engines, PGS decoders, ASS renderers, GPU shader programs, native plugins, FFI, VLC fallback behavior, diagnostics center integration, RSS automation, online rule runtime, WebView handling, DNS policy, or network policy.

The next change should move into Phase 6 only after this change is implemented and archived.
