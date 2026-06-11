## ADDED Requirements

### Requirement: RSS engine foundation SHALL support runtime composition
RSS engine foundation contracts SHALL support deterministic runtime composition of feed source registration, scheduler decisions, gateway-backed fetch handoff, parser handoff, deduplication, persisted accepted items, cursor metadata, and update emission without requiring source-specific scraping logic.

#### Scenario: Runtime composes foundation contracts
- **WHEN** the RSS engine runtime refreshes a registered source
- **THEN** `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, and `FeedDeduplicator` contracts compose the refresh pipeline without concrete UI, network client, seasonal indexer, auto-download, BT, online-rule, diagnostics, or native-player dependencies

### Requirement: RSS engine foundation SHALL expose deterministic scheduling inputs
RSS engine foundation contracts SHALL allow deterministic due-source projection from registered feed sources and scheduler decisions without requiring timers, platform background services, or concrete subscription UI.

#### Scenario: Scheduler reports due source
- **WHEN** a scheduler emits a due-source decision for a registered feed source
- **THEN** runtime actions can refresh that source through RSS engine contracts while preserving source neutrality and feed format compatibility

### Requirement: RSS engine foundation MUST remain parser and source neutral
RSS engine foundation MUST NOT specialize runtime behavior for yuc.wiki, seasonal anime normalization, Bangumi matching, RSS auto-download filtering, torrent enclosures, online-rule parsing, or concrete RSS/Atom parser packages.

#### Scenario: Mixed feed sources are registered
- **WHEN** RSS, Atom, YucWiki, or future feed sources are registered
- **THEN** they are represented through the same feed source, fetch, parse, schedule, and dedupe contracts before downstream consumers inspect accepted feed items
