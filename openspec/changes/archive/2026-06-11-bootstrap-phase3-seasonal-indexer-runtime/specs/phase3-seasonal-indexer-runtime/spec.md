## ADDED Requirements

### Requirement: Phase 3 seasonal indexer runtime SHALL compose RSS seasonal contracts
The system SHALL provide a deterministic Phase 3 seasonal indexer runtime or bootstrap that composes RSS accepted update consumption, seasonal feed source registration, seasonal consumers, seasonal catalog storage, Bangumi match queue storage, provider binding priority, and lifecycle snapshots behind Domain-facing runtime actions.

#### Scenario: Runtime is bootstrapped
- **WHEN** seasonal indexer runtime is created with deterministic RSS, seasonal consumer, catalog store, match queue store, and binding contracts
- **THEN** it exposes lifecycle-safe source, consumer, catalog, match queue, worker, update, and snapshot surfaces without concrete UI, yuc.wiki scraping, HTTP client, RSS auto-download, BT, online-rule, diagnostics, or native-player dependencies

### Requirement: Seasonal indexer runtime SHALL register YucWiki as a normal FeedSource
The runtime SHALL model YucWiki seasonal RSS as ordinary `FeedSource` metadata and consumer routing configuration processed through RSS engine contracts before seasonal normalization.

#### Scenario: YucWiki source is registered
- **WHEN** runtime registers the YucWiki seasonal RSS source
- **THEN** the source is represented as a normal feed source without adding scraper, crawler, source-specific parser, concrete HTTP client, cookie/session, UI subscription, or network implementation behavior

### Requirement: Seasonal indexer runtime SHALL consume accepted RSS updates deterministically
The runtime SHALL consume accepted `FeedItem` updates from RSS runtime or RSS engine contracts, map them to `SeasonalSourceItem` values, dispatch them to matching `SeasonalAnimeConsumer` instances, persist new seasonal catalog entries, and emit catalog updates.

#### Scenario: Accepted RSS update is consumed
- **WHEN** RSS runtime emits an accepted feed item for a seasonal feed source
- **THEN** seasonal runtime dispatches it to matching consumers, stores newly normalized catalog entries, suppresses existing source-item duplicates, and publishes catalog updates without changing RSS engine source-neutral behavior

### Requirement: Seasonal indexer runtime SHALL project Bangumi match queue work
The runtime SHALL enqueue normalized seasonal catalog entries for Bangumi match work and expose deterministic pending queue, candidate, processed, skipped, failed, and empty outcomes without making Bangumi enrichment mandatory for catalog indexing.

#### Scenario: Catalog entry is queued for matching
- **WHEN** a new seasonal catalog entry is persisted without an authoritative user-confirmed binding
- **THEN** runtime queues Bangumi match work with durable queue metadata while keeping the catalog entry available even if Bangumi provider lookup is unavailable

### Requirement: Seasonal indexer runtime SHALL preserve user-confirmed binding priority
The runtime SHALL never apply an automatic Bangumi match over an existing user-confirmed binding and SHALL report skipped automatic outcomes when user authority wins.

#### Scenario: Automatic match conflicts with user binding
- **WHEN** match processing finds a candidate for a seasonal catalog entry that already has a user-confirmed Bangumi binding
- **THEN** runtime records a skipped user-confirmed-binding outcome and leaves the user-confirmed binding authoritative

### Requirement: Seasonal indexer runtime SHALL provide lifecycle-safe action outcomes
The runtime SHALL return typed success, ignored, unavailable, failed, and disposed outcomes for source registration, update consumption, catalog projection, match queue projection, match processing, and update observation instead of leaking RSS, consumer, storage, provider, binding, or stream exceptions.

#### Scenario: Runtime is disposed
- **WHEN** source, consumption, catalog, queue, match, or observation actions are invoked after runtime disposal
- **THEN** the runtime returns disposed outcomes and closes update observation without executing RSS, consumer, storage, provider, RSS auto-download, BT, online-rule, diagnostics, UI, or native-player behavior
