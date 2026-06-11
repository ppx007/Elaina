# rss-engine-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-detail-library-seasonal. Update Purpose after archive.
## Requirements
### Requirement: RSS engine SHALL define source, fetcher, parser, and scheduler contracts
The system SHALL define reusable `FeedSource`, `FeedFetcher`, `FeedParser`, and `FeedScheduler` contracts for RSS and Atom feeds, and Domain RSS orchestration SHALL compose those contracts into a refresh pipeline without source-specific scraping logic.

#### Scenario: Feed source is scheduled
- **WHEN** a feed source is due for refresh
- **THEN** the scheduler invokes fetch and parse contracts without source-specific scraping logic

### Requirement: Feed items SHALL have stable deduplication keys
The system SHALL define feed item deduplication contracts using stable keys derived from feed item identity, and accepted dedupe keys SHALL be persistable through Storage-layer feed state.

#### Scenario: Same feed item appears twice
- **WHEN** a feed item with the same stable dedupe key appears in multiple fetches
- **THEN** the engine treats it as an existing item rather than a new entry

### Requirement: Feed network access MUST use gateway policy
Feed network access MUST use provider/gateway policy for retries, caching, cache validators, and normalized failures rather than source-specific transport logic.

#### Scenario: Feed fetch fails transiently
- **WHEN** a feed request fails with a retryable condition
- **THEN** the failure is represented through gateway-normalized semantics

### Requirement: RSS engine SHALL expose Domain refresh results
The system SHALL expose Domain-facing refresh results that identify the feed source, newly accepted items, warnings, and provider-normalized failure information.

#### Scenario: Feed refresh has new items
- **WHEN** a feed refresh accepts new items after parsing and deduplication
- **THEN** Domain receives a typed refresh result and update stream without depending on concrete provider classes

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

