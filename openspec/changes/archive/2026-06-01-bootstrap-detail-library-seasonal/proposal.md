## Why

Celesteria now has playback, subtitle, danmaku, and provider boundary contracts, so the next slice can connect those foundations into user-facing ACG organization without jumping ahead to BT, advanced playback, or online rule sources. Phase 3 defines the detail page, media library, SubtitleProvider, RSS engine, and seasonal indexing contracts that make local media and seasonal subscriptions coherent.

## What Changes

- Establish **Phase 3 / Step 13-17** as the next implementation boundary.
- Define video detail page data contracts for cover, summary, episode list, continue-watching state, and follow state.
- Define media library scanning, playback history, and provider binding-state contracts.
- Define `SubtitleProvider` contracts for external subtitle sources and cache behavior.
- Define RSS engine foundations: `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, and feed item deduplication.
- Define YucWiki RSS seasonal indexing as a normal `FeedSource` plus `SeasonalAnimeConsumer` and Bangumi match queue.

## Capabilities

### New Capabilities
- `video-detail-page-contract`: Defines the Domain data contract that a video detail page consumes.
- `media-library-foundation`: Defines local media scanning, playback history, and provider binding-state contracts.
- `subtitle-provider-boundary`: Defines external subtitle provider registration, provider traffic, and cache behavior.
- `rss-engine-foundation`: Defines reusable RSS/Atom feed source, fetch, parse, schedule, and deduplication contracts.
- `seasonal-anime-indexer`: Defines YucWiki RSS seasonal indexing through the RSS engine and Bangumi match queue.

### Modified Capabilities

None.

## Impact

- Adds Domain, Provider, Storage, Gateway, and UI-facing contracts that sit above the archived playback and ACG provider foundations.
- Requires all external provider and feed traffic to use `ProviderGateway` policies where network access is involved.
- Keeps `yuc.wiki` as an RSS `FeedSource`, not a hardcoded special scraper.
- Keeps BT streaming, online rule sources, Anime4K, VLC fallback, DNS policy, WebView challenge handling, and diagnostics center out of scope.
