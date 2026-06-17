# phase3-rss-engine-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase3-rss-engine-runtime. Update Purpose after archive.
## Requirements
### Requirement: Phase 3 RSS engine runtime SHALL compose feed engine contracts
The system SHALL provide a deterministic Phase 3 RSS engine runtime or bootstrap that composes feed source registry, feed scheduler, RSS engine contract, RSS feed store, feed fetcher, feed parser, feed deduplicator, and update emission behind Domain-facing runtime actions.

#### Scenario: Runtime is bootstrapped
- **WHEN** RSS engine runtime is created with deterministic feed contracts
- **THEN** it exposes lifecycle-safe source, schedule, refresh, cursor, dedupe, accepted-item, and update surfaces without concrete UI, HTTP client, seasonal indexer, auto-download, BT, online-rule, diagnostics, or native-player dependencies

### Requirement: RSS engine runtime SHALL expose source registry snapshots
The runtime SHALL expose immutable snapshots of registered feed sources, latest refresh outcomes, accepted update counts, known cursor metadata, and lifecycle state from existing RSS feed store and engine contracts.

#### Scenario: Source registry changes
- **WHEN** a feed source is registered or removed through runtime actions
- **THEN** runtime snapshots reflect the source registry state without requiring Flutter widgets, concrete storage implementations, yuc.wiki-specific logic, or platform background services

### Requirement: RSS engine runtime SHALL refresh one or more due sources deterministically
The runtime SHALL consume scheduler decisions or explicit refresh requests to refresh individual or due feed sources through existing feed engine contracts, preserving parser warnings, gateway-normalized failures, cursor validators, and accepted item updates.

#### Scenario: Due source refresh succeeds
- **WHEN** the runtime refreshes a due RSS or Atom source
- **THEN** it fetches through `FeedFetcher`, parses through `FeedParser`, suppresses duplicates through dedupe contracts and persisted dedupe keys, stores accepted items, saves cursor metadata, and emits only accepted updates

### Requirement: RSS engine runtime SHALL provide lifecycle-safe action outcomes
The runtime SHALL return typed success, ignored, unavailable, failed, and disposed outcomes for source registration, source listing, due-source projection, refresh, and update observation instead of leaking provider, storage, parser, scheduler, or stream exceptions.

#### Scenario: Runtime is disposed
- **WHEN** source or refresh actions are invoked after runtime disposal
- **THEN** the runtime returns disposed outcomes and closes update observation without executing fetch, parse, persistence, seasonal, auto-download, BT, online-rule, diagnostics, UI, or native-player behavior

### Requirement: RSS engine runtime MUST remain source-neutral
The runtime MUST model yuc.wiki and future feed sources as normal `FeedSource` values and MUST NOT add source-specific scraping, seasonal normalization, Bangumi matching, RSS auto-download filtering, torrent task creation, online-rule parsing, or UI-specific behavior.

#### Scenario: YucWiki feed source is registered
- **WHEN** the YucWiki seasonal RSS source or any other RSS source is registered
- **THEN** the runtime treats it as a generic feed source processed through RSS engine contracts before any downstream consumer-specific behavior

### Requirement: RSS engine runtime SHALL isolate downstream seasonal consumers
RSS engine runtime SHALL expose accepted feed updates that downstream seasonal consumers can observe without making RSS source registration, fetch, parse, dedupe, cursor, refresh, or lifecycle behavior depend on seasonal indexing, YucWiki-specific logic, Bangumi matching, RSS auto-download, BT, online-rule, diagnostics, UI, or native-player behavior.

#### Scenario: Seasonal consumer observes accepted update
- **WHEN** RSS runtime emits an accepted feed item for a registered seasonal feed source
- **THEN** seasonal indexer runtime can consume the item downstream without changing RSS runtime snapshots, source neutrality, fetch semantics, parser behavior, dedupe behavior, or refresh outcomes

### Requirement: RSS engine runtime MUST NOT own seasonal failure semantics
RSS engine runtime MUST NOT convert seasonal consumer, catalog persistence, Bangumi match queue, automatic binding, or seasonal catalog failures into RSS refresh failures.

#### Scenario: Seasonal indexing fails after RSS refresh
- **WHEN** RSS runtime successfully accepts and emits a feed item but downstream seasonal indexing fails
- **THEN** RSS refresh remains successful and the seasonal runtime reports its own typed failure independently

### Requirement: RSS engine runtime SHALL compose concrete RSS/Atom adapters
RSS engine runtime SHALL be able to compose the concrete Provider-layer HTTP
fetcher and RSS/Atom XML parsers through existing runtime bootstrap arguments.

#### Scenario: Runtime refreshes with concrete adapters
- **WHEN** the runtime registers a source and refreshes it with concrete feed
  fetch and parse adapters
- **THEN** accepted feed items, parser warnings, cursor validators, dedupe
  state, and update streams behave the same as deterministic feed contracts
  without requiring UI, live source management pages, seasonal indexing, RSS
  auto-download, BT, online rules, diagnostics, network-policy
  implementation, or native player bindings

### Requirement: RSS engine runtime SHALL participate in the automation smoke gate
The RSS engine runtime SHALL support a non-UI smoke path that composes concrete
RSS fetch/parse adapters through existing bootstrap arguments and exposes
accepted feed items to downstream seasonal flow validation.

#### Scenario: Automation smoke gate refreshes a feed source
- **WHEN** the automation smoke gate registers and refreshes a feed source
  through the Step 46 fetcher/parser and RSS runtime bootstrap
- **THEN** the refresh succeeds, accepted feed items are produced, cursor
  request metadata remains observable, and RSS runtime behavior remains
  source-neutral without requiring UI, live source pages, RSS auto-download,
  BT, online rule internals, diagnostics actions, or native player behavior

