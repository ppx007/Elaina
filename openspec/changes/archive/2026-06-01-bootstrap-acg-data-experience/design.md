## Context

`bootstrap-player-core` has been archived and its player specs now live under `openspec/specs/`. The architecture plan defines Phase 2 as Step 9 basic subtitles, Step 10 BangumiProvider, Step 11 DandanplayProvider, and Step 12 basic danmaku.

This slice is the first ACG-specific experience layer. It must not turn provider integrations into playback prerequisites. Local/HTTP/HLS playback must continue to work without Bangumi, Dandanplay, subtitle providers, RSS, BT, or rule-source systems. All provider traffic must flow through `ProviderGateway`; UI must consume Domain/Playback contracts rather than provider SDKs.

## Goals / Non-Goals

**Goals:**
- Define basic subtitle parser contracts for SRT, VTT, and ASS plus local external subtitle scanning and external subtitle offset behavior.
- Define Bangumi provider contracts for subject, episode, OAuth/session state, and progress sync.
- Define Dandanplay provider contracts for matching, search, comment retrieval, and comment posting.
- Define basic danmaku rendering modes for scrolling, top, and bottom comments with filtering and density controls.
- Keep subtitle and danmaku timing aligned to the player clock, not wall clock.

**Non-Goals:**
- Building video detail pages, media library, or binding-state UI.
- Adding subtitle provider integrations such as OpenSubtitles.
- Adding RSS engine, yuc.wiki seasonal indexing, online rule sources, BT streaming, Anime4K, VLC fallback, or diagnostics center.
- Implementing automatic captcha solving. Any web challenge flow must remain manual completion plus same-origin session backfill in a later change.
- Making Bangumi or Dandanplay required for core playback.

## Decisions

### 1. Keep subtitles local and parser-focused in this slice

Step 9 covers basic subtitles, local external subtitle scanning, and external subtitle offset. Subtitle provider discovery belongs to a later phase. The subtitle core should discover media-adjacent local subtitle candidates, parse and time subtitle cues, and avoid fetching from external services.

**Alternative considered:** add provider-backed subtitle search now. Rejected because the architecture plan puts `SubtitleProvider` in Phase 3.

### 2. Route Bangumi and Dandanplay through ProviderGateway

Both providers must register rate policies and use gateway request governance. This keeps retries, deduplication, caching, and provider failure semantics consistent with archived Phase 0 specs.

**Alternative considered:** let each provider own its HTTP client and cache behavior. Rejected because it duplicates the exact network governance Phase 0 froze.

### 3. Treat provider data as optional enrichment, not playback dependency

Bangumi metadata, Dandanplay matches, comments, and progress sync enhance the ACG experience but cannot block media playback. Domain flows must tolerate missing, unauthenticated, throttled, or failed provider responses.

**Alternative considered:** force provider binding before playback features appear. Rejected because the architecture plan explicitly says online/provider features cannot be core playback prerequisites.

### 4. Keep danmaku basic and player-clock aligned

Phase 2 danmaku covers scrolling, top, bottom, filtering, and density. Advanced matrix effects, dual subtitle interactions, high-performance overlays, and diagnostics belong later. Danmaku timing must follow `PlayerClock` rather than wall clock.

## Risks / Trade-offs

- **[Risk] Provider work leaks SDKs into UI** -> **Mitigation:** expose provider results through Domain contracts and extend checks for provider SDK terms in UI files.
- **[Risk] Playback accidentally depends on provider availability** -> **Mitigation:** keep provider flows optional and failure-tolerant.
- **[Risk] Danmaku timing drifts from playback** -> **Mitigation:** define renderer timing against player clock contracts.
- **[Risk] Subtitle scope expands into provider search or advanced formats** -> **Mitigation:** limit this slice to SRT, VTT, ASS, media-adjacent local subtitle scanning, external references, and offset behavior.

## Migration Plan

This is a greenfield continuation from Phase 1:

1. Add subtitle cue, parser, source, local external scanning, and offset contracts.
2. Add Bangumi provider boundary contracts through `ProviderGateway`.
3. Add Dandanplay provider boundary contracts through `ProviderGateway`.
4. Add basic danmaku event, filter, density, and renderer contracts tied to player clock.
5. Add verification that provider work does not regress playback, gateway, or UI boundary rules.

## Open Questions

- Which concrete Bangumi and Dandanplay API client packages, if any, should back the first provider implementations?
- Should OAuth/session persistence be represented first as provider state contracts only, or should it add concrete storage tables in the same apply pass?
- Should ASS parsing start as a reduced cue model or preserve full ASS style metadata for later advanced rendering?
