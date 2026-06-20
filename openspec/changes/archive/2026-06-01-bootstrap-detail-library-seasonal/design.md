## Context

`bootstrap-acg-data-experience` has been archived, so Elaina now has contracts for subtitles, Bangumi, Dandanplay, danmaku, provider results, and provider gateway boundaries. The architecture plan defines Phase 3 as Step 13 video detail page, Step 14 media library, Step 15 SubtitleProvider, Step 16 RSS engine, and Step 17 YucWiki RSS seasonal indexer.

This slice connects local media organization and seasonal subscription data without making online sources or RSS mandatory for playback. Detail page data must flow through Domain contracts. Feed and provider traffic must flow through `ProviderGateway`. YucWiki is a normal RSS source and must not become a special scraper.

## Goals / Non-Goals

**Goals:**
- Define the video detail page Domain contract for cover, summary, episodes, continue watching, and follow state.
- Define media library scan, playback history, and binding-state contracts.
- Define external subtitle provider contracts and cache behavior through provider/gateway boundaries.
- Define reusable RSS/Atom source, fetcher, parser, scheduler, and deduplication contracts.
- Define seasonal anime indexing from YucWiki RSS items into normalized season entries and a Bangumi match queue.

**Non-Goals:**
- Building the final visual detail page UI or media library UI.
- Implementing BT tasks, virtual media streams, RSS auto-download, online rule sources, WebView challenge handling, DNS policy, Anime4K, VLC fallback, or diagnostics center.
- Treating yuc.wiki as a special scraper outside the RSS engine.
- Auto-solving captchas or adding browser challenge automation.

## Decisions

### 1. Detail page consumes Domain view data only

The detail page contract will expose a view data model assembled from local media, playback history, provider metadata, and binding state. UI must not call Bangumi, Dandanplay, subtitle providers, or RSS sources directly.

**Alternative considered:** let the page fetch provider data directly for speed. Rejected because it violates the archived layer and provider gateway constraints.

### 2. Media library owns local scan and history contracts

The media library foundation defines local media identity, scan candidates, history, and binding state. Later WebDAV, SMB, Jellyfin, and other scanners can extend the scanner seam without changing the detail page contract.

### 3. SubtitleProvider is external-source discovery, not basic subtitle parsing

Basic local subtitle parsing already exists. This change adds external subtitle provider boundaries, provider registration, and cache behavior. Providers must use `ProviderGateway` and must not bypass the existing subtitle parser contracts when returning files.

### 4. RSS engine is reusable and source-neutral

`FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, and deduplication are defined independently of yuc.wiki. RSS and Atom should both fit the same contracts.

### 5. YucWiki seasonal indexing is a FeedSource plus consumer

YucWiki items are fetched and parsed by the RSS engine, consumed by `SeasonalAnimeConsumer`, normalized into seasonal catalog entries, and queued for Bangumi matching through provider/gateway rules. It is not a custom scraping lane.

## Risks / Trade-offs

- **[Risk] Detail page grows into a full product UI** -> **Mitigation:** this change defines data contracts and state shape, not final screen styling.
- **[Risk] RSS/yuc.wiki bypasses ProviderGateway or feed contracts** -> **Mitigation:** require feed source registration and gateway-backed fetch behavior.
- **[Risk] SubtitleProvider duplicates basic subtitle parsing** -> **Mitigation:** providers discover or retrieve external subtitle candidates; parsing remains in `basic-subtitle-core`.
- **[Risk] Seasonal matching overwrites user-confirmed binding** -> **Mitigation:** define user-confirmed binding as higher priority than automatic matches.

## Migration Plan

This is a greenfield continuation from Phase 2:

1. Add detail-page view data and episode list contracts.
2. Add media library scan, history, and binding-state contracts.
3. Add subtitle provider boundary and cache contracts.
4. Add RSS engine source/fetch/parse/schedule/dedupe contracts.
5. Add YucWiki RSS seasonal consumer and Bangumi match queue contracts.

## Open Questions

- Which local media filename normalization rules should be used before provider matching?
- Should subtitle provider cache metadata live in generic provider cache entries or a subtitle-specific read model?
- How much RSS parser tolerance is required for malformed feeds in the first implementation pass?
