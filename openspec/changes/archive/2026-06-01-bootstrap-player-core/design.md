## Context

`bootstrap-phase-0-foundation` has been archived and its foundation specs now live under `openspec/specs/`. The architecture plan defines Phase 1 as player core: Step 5 MPV Adapter, Step 6 Capability Matrix, Step 7 playback page foundation, and Step 8 track management.

The player core must build on the Phase 0 layer boundaries. UI cannot import MPV, VLC, native player bindings, provider implementations, or storage internals. The playback page may become visible in this change, but it must remain capability-driven and must not pull in provider-specific metadata, danmaku, subtitles beyond track selection, RSS, BT streaming, Anime4K, or diagnostics center work.

## Goals / Non-Goals

**Goals:**
- Define the replaceable MPV adapter boundary for local file, HTTP, and HLS playback.
- Define the capability matrix used by UI and Domain code to decide which playback controls and panels are available.
- Define the playback page foundation as a thin UI shell driven by playback capability declarations.
- Define audio and subtitle track discovery and switching contracts.
- Preserve the path for future VLC, ExoPlayer, AVPlayer, and platform adapters.

**Non-Goals:**
- Integrating Bangumi, Dandanplay, RSS, subtitle providers, BT streaming, online rule parsing, Anime4K, VLC fallback, or diagnostics center.
- Implementing advanced subtitle rendering, danmaku rendering, matrix effects, dual subtitle mode, or PGS support.
- Making online source parsing or provider metadata a prerequisite for local/HTTP/HLS playback.
- Adding long-running platform download behavior.

## Decisions

### 1. Keep MPV behind a PlayerAdapter facade

The MPV adapter will be the first playback target, but all consumers must depend on `PlayerAdapter` and capability contracts. The implementation must provide an MPV-specific facade in the Playback layer. If the concrete native binding is not available in the current environment, the facade must report local file, HTTP, and HLS playback as unsupported through the capability matrix rather than claiming playback support. This keeps media-kit/libmpv replaceable and leaves room for VLC, ExoPlayer, AVPlayer, and platform adapters later.

**Alternative considered:** wire UI directly to MPV bindings for faster visible playback. Rejected because it violates the Phase 0 layer boundary and makes future fallback adapters harder.

### 2. Make the capability matrix authoritative for playback UI

The playback page must show or hide controls based on capability declarations from the active adapter and platform. This prevents unsupported controls from leaking into UI and keeps future adapter variation explicit.

**Alternative considered:** hard-code controls based on the initial MPV adapter. Rejected because Phase 1 explicitly introduces the Capability Matrix as a freeze point.

### 3. Treat the playback page as a foundation, not a full player experience

This change may define the video surface, playback controls, progress, and secondary panel entry points, but it does not implement advanced panels or provider-driven content. The page is a shell over player core contracts.

**Alternative considered:** build the rich playback page now. Rejected because subtitles, danmaku, enhancement, diagnostics, and provider metadata belong to later phases.

### 4. Track management starts with audio and subtitle tracks only

Step 8 covers audio and subtitle track discovery and switching. Chapter tracks, external subtitle scanning, advanced subtitle formats, and provider subtitle sources remain later work.

## Risks / Trade-offs

- **[Risk] MPV leaks into UI through convenience imports** -> **Mitigation:** keep MPV behind adapter contracts and extend the Phase 0 checker for playback-layer imports during implementation.
- **[Risk] Capability matrix becomes a static feature list** -> **Mitigation:** make capabilities adapter- and platform-scoped, not global constants.
- **[Risk] Playback page scope expands into advanced media UX** -> **Mitigation:** keep advanced functions as disabled or absent secondary panel entry points until later phases define them.
- **[Risk] Track switching assumes all adapters expose identical track data** -> **Mitigation:** define normalized track descriptors and unsupported-state semantics.

## Migration Plan

This is a greenfield continuation from Phase 0:

1. Add player-core contracts under the existing Playback layer.
2. Add MPV adapter boundary and source-type contracts without binding to a concrete native implementation in UI.
3. Add capability matrix declarations and adapter capability reporting.
4. Add playback page foundation that consumes Domain/Playback abstractions only.
5. Add track discovery and switching contracts.

## Open Questions

- Should the first playback page be a Flutter app screen in this change, or should this change stop at UI contracts until the Flutter SDK is available?
- Which static check should enforce that playback UI cannot import concrete MPV/native bindings?
