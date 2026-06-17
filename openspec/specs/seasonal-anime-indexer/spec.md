# seasonal-anime-indexer Specification

## Purpose
TBD - created by archiving change bootstrap-detail-library-seasonal. Update Purpose after archive.
## Requirements
### Requirement: YucWiki SHALL be modeled as a FeedSource
The system SHALL model yuc.wiki seasonal data as a normal RSS `FeedSource` processed by the RSS engine and seasonal consumer pipeline, not as a special scraper.

#### Scenario: YucWiki source is refreshed
- **WHEN** the yuc.wiki RSS source is refreshed
- **THEN** it is fetched, parsed, scheduled, and deduplicated through RSS engine contracts before seasonal normalization occurs

### Requirement: SeasonalAnimeConsumer SHALL normalize feed items
The system SHALL define a `SeasonalAnimeConsumer` that consumes feed items and normalizes them into seasonal catalog entries persisted through Storage contracts.

#### Scenario: Seasonal feed item is consumed
- **WHEN** a seasonal feed item is accepted by the consumer
- **THEN** it is normalized into a seasonal catalog entry suitable for persistence and later matching

### Requirement: Bangumi match queue MUST respect binding priority
The system MUST define a Bangumi match queue for seasonal catalog entries that never overrides user-confirmed Bangumi bindings and records skipped automatic outcomes when such bindings exist.

#### Scenario: Automatic match candidate conflicts with user binding
- **WHEN** a match queue candidate conflicts with a user-confirmed binding
- **THEN** the user-confirmed binding remains authoritative and the automatic candidate is treated as lower priority

### Requirement: Seasonal anime indexer SHALL support runtime composition
Seasonal anime indexer contracts SHALL support deterministic runtime composition of YucWiki feed source registration, RSS accepted item consumption, seasonal consumer dispatch, normalized catalog persistence, match queue enqueueing, catalog update emission, and lifecycle validation while keeping YucWiki source-neutral.

#### Scenario: Runtime composes seasonal indexer contracts
- **WHEN** seasonal indexer runtime consumes an accepted YucWiki RSS item
- **THEN** `SeasonalAnimeConsumer`, seasonal catalog storage, and Bangumi match queue contracts compose the indexer pipeline without concrete UI, scraper, crawler, HTTP client, RSS auto-download, BT, online-rule, diagnostics, or native-player dependencies

### Requirement: Seasonal anime indexer SHALL expose catalog snapshots
Seasonal anime indexer runtime SHALL expose immutable snapshots of registered seasonal sources, active consumers, catalog entries, pending match queue work, latest outcomes, and lifecycle state from existing seasonal contracts and stores.

#### Scenario: Catalog state changes
- **WHEN** a seasonal feed item is normalized into a catalog entry
- **THEN** runtime snapshots reflect the catalog and match queue state without requiring Flutter widgets, concrete storage implementations, yuc.wiki-specific scraping, platform background services, or diagnostics integration

### Requirement: Seasonal anime indexer MUST keep YucWiki source-neutral
Seasonal anime indexer runtime MUST NOT add yuc.wiki-specific scraping, crawler behavior, concrete feed transport, concrete RSS parser packages, UI subscription behavior, RSS auto-download filtering, torrent task creation, online-rule parsing, or native-player behavior.

#### Scenario: Future seasonal feed source is registered
- **WHEN** a future seasonal RSS or Atom feed source is registered beside YucWiki
- **THEN** it is represented through the same feed source, consumer, catalog, and match queue contracts before downstream consumers inspect normalized entries

### Requirement: Seasonal anime flow SHALL connect RSS refresh to Bangumi queue
The seasonal anime indexer SHALL support a concrete non-UI flow from RSS source
refresh through seasonal catalog persistence and Bangumi match queue enqueueing.

#### Scenario: RSS source produces accepted seasonal items
- **WHEN** an RSS source refresh produces accepted feed items
- **THEN** the seasonal flow converts those items into catalog entries, stores
  them, enqueues Bangumi match work, and exposes the resulting queue projection
  without requiring RSS pages, UI subscription management, RSS auto-download,
  BT tasks, online-rule evaluation, diagnostics, WebView, or native-player
  integrations

