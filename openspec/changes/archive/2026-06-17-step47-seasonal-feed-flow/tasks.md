## 1. OpenSpec

- [x] 1.1 Create change `step47-seasonal-feed-flow`.
- [x] 1.2 Add spec deltas for seasonal feed flow behavior and boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step47-seasonal-feed-flow" --json`.

## 2. Core Flow

- [x] 2.1 Add `FeedItemSeasonalAnimeConsumer` using explicit source id, season, and named catalog id prefix.
- [x] 2.2 Add `SeasonalFeedFlowRuntime` to register sources, refresh RSS sources, consume accepted items, and project match queue state.
- [x] 2.3 Add `SeasonalFeedFlowBootstrap` to compose existing `RssEngineBootstrap` and `SeasonalIndexerBootstrap` without UI or concrete platform dependencies.
- [x] 2.4 Preserve existing RSS and seasonal contracts instead of adding parallel feed, catalog, or queue models.

## 3. Boundaries

- [x] 3.1 Keep `dart:io`, `HttpClient`, XML parser imports, and concrete feed transport details out of Domain seasonal flow files.
- [x] 3.2 Keep UI, app shell, RSS pages, file pickers, native player, BT, RSS auto-download, online-rule, diagnostics, WebView, and network-policy implementations outside the change.
- [x] 3.3 Keep yuc.wiki as ordinary `FeedSource` data; do not add source-specific scraper behavior.
- [x] 3.4 Avoid new inline magic values for catalog id prefixes or thresholds.

## 4. Tests And Checkers

- [x] 4.1 Add focused tests for concrete RSS fetch/parser -> seasonal catalog -> Bangumi queue flow.
- [x] 4.2 Add focused tests for not-modified refresh, source registration, failure normalization, and disposal.
- [x] 4.3 Add non-UI smoke checker proving Step 46 concrete fetch/parser composes with Step 47 seasonal flow.
- [x] 4.4 Extend seasonal checker to require Step 47 flow files while preserving Domain/runtime boundaries.
- [x] 4.5 Add integration notes for app composition without editing UI files.

## 5. Validation And Archive

- [x] 5.1 Run focused seasonal flow tests and checker.
- [x] 5.2 Run `openspec.cmd validate "step47-seasonal-feed-flow" --strict`.
- [x] 5.3 Run baseline validation gates.
- [x] 5.4 Archive the OpenSpec change.
- [x] 5.5 Re-run `openspec.cmd validate --all` and report git status.
