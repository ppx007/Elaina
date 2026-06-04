## 1. Seasonal storage persistence

- [x] 1.1 Add seasonal catalog entry records, Bangumi match candidate records, queue item records, and queue status values. Layers: Storage, Domain
- [x] 1.2 Add `SeasonalCatalogStore` and `BangumiMatchQueueStore` contracts with deterministic implementations. Layers: Storage
- [x] 1.3 Expose seasonal catalog and Bangumi match queue responsibilities through `StorageFoundation`. Layers: Storage

## 2. Domain seasonal indexing orchestration

- [x] 2.1 Add RSS-to-seasonal source item mapping that preserves feed source id, item id, title, link, summary, and published timestamp. Layers: Domain
- [x] 2.2 Add `SeasonalIndexerContract` that consumes `RssEngineContract.updates` and dispatches accepted seasonal items to matching `SeasonalAnimeConsumer` instances without triggering feed refreshes. Layers: Domain
- [x] 2.3 Persist normalized seasonal catalog entries and avoid duplicate catalog entries for already-seen source items. Layers: Domain, Storage
- [x] 2.4 Keep yuc.wiki behavior as `FeedSource` plus consumer normalization only, with no scraper, HTTP client, XML parser, or RSS core special case. Layers: Domain, Provider

## 3. Bangumi match queue and invalidation

- [x] 3.1 Add a Bangumi match worker contract that searches candidates through `BangumiProvider.searchSubjects()`, applies the deterministic `0.8` confidence threshold, and persists normalized candidates. Layers: Domain, Provider, Storage
- [x] 3.2 Apply automatic matches through provider binding contracts while preserving user-confirmed binding priority. Layers: Domain, Storage
- [x] 3.3 Add cache invalidation events for seasonal catalog updates, Bangumi match enqueueing, and automatic match application. Layers: Foundation, Domain

## 4. Verification and guardrails

- [x] 4.1 Add deterministic contract tests for catalog persistence, RSS update dispatch, consumer normalization, deduplication, queue persistence, provider failure propagation, and user-confirmed binding priority. Layers: Test
- [x] 4.2 Update runtime validation to cover seasonal indexer and match queue contracts. Layers: Tools
- [x] 4.3 Update boundary checker scripts to enforce no UI/provider storage bypass, no yuc.wiki scraper path, and no RSS auto-download or BT behavior in Step 17. Layers: Tools
