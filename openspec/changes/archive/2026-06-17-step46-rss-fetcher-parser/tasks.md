## 1. OpenSpec

- [x] 1.1 Create change `step46-rss-fetcher-parser`.
- [x] 1.2 Add spec deltas for concrete RSS/Atom fetch/parser behavior and boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step46-rss-fetcher-parser" --json`.

## 2. Concrete Fetch And Parse

- [x] 2.1 Add Provider-layer HTTP feed transport/fetcher using existing `FeedFetcher` and `ProviderGateway` contracts.
- [x] 2.2 Preserve ETag and Last-Modified request/response metadata, including not-modified responses.
- [x] 2.3 Add RSS XML parser for item title/link/guid/date/summary/categories/enclosure.
- [x] 2.4 Add Atom XML parser for entry title/id/link/date/summary/categories/enclosure.
- [x] 2.5 Reuse existing `FeedSource`, `FeedItem`, `FeedDedupeKey`, `FeedParser`, and `RssEngineRuntime` surfaces instead of adding parallel models.

## 3. Boundaries

- [x] 3.1 Keep `dart:io`, `HttpClient`, XML package imports, and transport details out of `lib/src/domain/rss/**`.
- [x] 3.2 Keep UI, app shell, RSS pages, file pickers, native player, BT, RSS auto-download, seasonal indexing, online-rule, diagnostics, WebView, and network-policy implementations outside the change.
- [x] 3.3 Keep yuc.wiki as ordinary `FeedSource` data; do not add source-specific scraper behavior.

## 4. Tests And Checkers

- [x] 4.1 Add focused tests for HTTP fetch success, validators, not-modified, and normalized failures.
- [x] 4.2 Add focused tests for RSS and Atom parser output and malformed-feed failures.
- [x] 4.3 Add non-UI smoke checker proving concrete fetch/parser composes with `RssEngineBootstrap`.
- [x] 4.4 Extend RSS engine checker to require Step 46 concrete provider files while preserving Domain/runtime boundaries.
- [x] 4.5 Add integration notes for app composition without editing UI files.

## 5. Validation And Archive

- [x] 5.1 Run focused RSS tests and checker.
- [x] 5.2 Run `openspec.cmd validate "step46-rss-fetcher-parser" --strict`.
- [x] 5.3 Run baseline validation gates.
- [x] 5.4 Archive the OpenSpec change.
- [x] 5.5 Re-run `openspec.cmd validate --all` and report git status.
