# Phase 2 ACG Data Experience Contracts

This document records the implementation boundary for `bootstrap-acg-data-experience`, covering Phase 2 / Step 9-12 from `docs/elaina-architecture-plan.md`.

## Scope

1. Basic subtitle source, parser, offset, and local external scanning contracts for SRT, VTT, and ASS.
2. Bangumi subject, episode, OAuth/session, and progress-sync provider boundaries.
3. Dandanplay match, search, comment retrieval, and comment posting provider boundaries.
4. Basic danmaku event, filter, density, and renderer contracts.

## Provider Policy

Bangumi and Dandanplay traffic must route through `ProviderGateway`. Provider failures are optional enrichment failures and must not block core playback.

## Subtitle Policy

Local external subtitle scanning is limited to media-adjacent local candidates. Provider-backed subtitle discovery remains out of scope until a later SubtitleProvider change.

## Danmaku Timing Policy

Danmaku comments and subtitle offsets use player-clock positions rather than wall-clock timers.

## Excluded From This Slice

- Video detail page and media library.
- Subtitle provider integrations such as OpenSubtitles.
- RSS engine and yuc.wiki seasonal indexing.
- BT streaming, online rule sources, Anime4K, VLC fallback, and diagnostics center.
