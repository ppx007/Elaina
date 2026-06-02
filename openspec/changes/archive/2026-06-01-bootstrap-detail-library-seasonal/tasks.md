## 1. Video detail page contract

- [x] 1.1 Define video detail view data for cover, summary, episode list, continue-watching state, and follow state.
- [x] 1.2 Define detail page data composition through Domain contracts without UI direct provider access.
- [x] 1.3 Define detail page action boundaries for continue playback, episode selection, follow/unfollow, and secondary actions.

## 2. Media library foundation

- [x] 2.1 Define local media identity, scan candidate, and media item contracts.
- [x] 2.2 Define playback history and continue-watching contracts backed by Storage-layer responsibilities.
- [x] 2.3 Define provider binding-state contracts where user-confirmed bindings outrank automatic matches.

## 3. Subtitle provider boundary

- [x] 3.1 Define `SubtitleProvider` registration and search/retrieval contracts for external subtitle sources.
- [x] 3.2 Define subtitle provider cache behavior through `ProviderGateway` and Storage contracts.
- [x] 3.3 Ensure subtitle providers return subtitle candidates that remain compatible with `basic-subtitle-core` parsing contracts.

## 4. RSS engine foundation

- [x] 4.1 Define `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, and feed item contracts for RSS/Atom.
- [x] 4.2 Define feed item deduplication contracts and stable dedupe keys.
- [x] 4.3 Ensure feed network access uses provider/gateway policy rather than source-specific transport logic.

## 5. Seasonal anime indexer

- [x] 5.1 Define YucWiki RSS as a normal `FeedSource`, not a special scraper.
- [x] 5.2 Define `SeasonalAnimeConsumer`, normalized seasonal catalog entries, and Bangumi match queue contracts.
- [x] 5.3 Define automatic match behavior that never overrides user-confirmed Bangumi bindings.

## 6. Verification and next boundary

- [x] 6.1 Verify UI does not import provider SDKs, RSS/yuc.wiki fetchers, or concrete storage implementations.
- [x] 6.2 Verify RSS/yuc.wiki work does not introduce online rule-source parsing or RSS auto-download behavior.
- [x] 6.3 Verify Phase 4 / Step 18-21 BT playback work remains out of scope for this change.
