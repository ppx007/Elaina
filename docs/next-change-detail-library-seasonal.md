# Next Change Boundary: Phase 3 Detail, Library, Subtitle Provider, RSS, Seasonal Index

Start this change only after `bootstrap-acg-data-experience` is implemented and archived.

## Scope

- Step 13: Video detail page data contract for cover, summary, episodes, continue watching, and follow state.
- Step 14: Media library scanning, history, and binding-state contracts.
- Step 15: SubtitleProvider boundary for external subtitle sources and cache behavior.
- Step 16: RSS engine foundation with FeedSource, FeedFetcher, FeedParser, FeedScheduler, and deduplication.
- Step 17: YucWiki RSS seasonal indexer as a normal FeedSource plus SeasonalAnimeConsumer and Bangumi match queue.

## Carry-Forward Checks

- yuc.wiki remains a FeedSource, not a special scraper.
- Provider traffic remains behind `ProviderGateway`.
- UI remains dependent on Domain/Playback contracts, not provider SDKs.
