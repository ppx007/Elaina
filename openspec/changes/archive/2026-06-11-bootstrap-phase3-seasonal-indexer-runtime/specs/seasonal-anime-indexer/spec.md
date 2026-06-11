## ADDED Requirements

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
