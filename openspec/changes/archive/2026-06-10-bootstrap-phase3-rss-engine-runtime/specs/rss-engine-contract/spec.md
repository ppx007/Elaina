## ADDED Requirements

### Requirement: RSS engine contract SHALL support runtime source registry actions
RSS engine contracts SHALL support runtime registration, listing, lookup, and removal of feed sources through `RssFeedStore` and Domain-facing runtime action outcomes without concrete database implementation details.

#### Scenario: Runtime lists registered sources
- **WHEN** the RSS engine runtime requests the source registry snapshot
- **THEN** it reads registered feed sources from RSS feed storage contracts and exposes immutable Domain values without invoking fetchers, parsers, seasonal consumers, auto-download policies, or UI code

### Requirement: RSS engine contract SHALL preserve cursor validators through runtime refresh
RSS engine runtime refresh actions SHALL preserve ETag and last-modified metadata by loading cursor records before fetch and saving cursor records after successful fetch responses.

#### Scenario: Runtime refreshes a source repeatedly
- **WHEN** a source has a stored RSS cursor with ETag or last-modified metadata
- **THEN** the next runtime refresh sends those validators through `FeedFetchRequest` and updates cursor state from `FeedFetchResponse`

### Requirement: RSS engine contract SHALL combine in-memory and persisted deduplication
RSS engine runtime refresh actions SHALL suppress duplicate feed items using both `FeedDeduplicator.retainNewItems` and persisted dedupe keys from `RssFeedStore` before accepted items are stored or emitted.

#### Scenario: Duplicate item appears after restart
- **WHEN** a parsed feed item has a dedupe key already recorded in RSS feed storage
- **THEN** the runtime does not store or emit that item as a new update even if the in-memory deduplicator has no prior state

### Requirement: RSS engine contract SHALL expose accepted feed updates for downstream consumers
RSS engine runtime SHALL expose accepted feed item updates from Domain-facing results or streams so later seasonal indexers and RSS auto-download policies can consume parsed, deduplicated feed items without owning fetch, parse, schedule, or source-specific scraping behavior.

#### Scenario: Runtime accepts new feed items
- **WHEN** a refresh accepts new feed items
- **THEN** accepted items are visible through runtime refresh results and update observation before downstream consumers perform seasonal or automation-specific processing

### Requirement: RSS engine contract MUST normalize unavailable and failure outcomes
RSS engine runtime SHALL return typed unavailable, failed, ignored, and disposed outcomes for missing sources, parser format mismatch, provider fetch failures, storage failures, scheduler failures, and disposed runtime state.

#### Scenario: Feed fetch fails
- **WHEN** `FeedFetcher` returns a gateway-normalized provider failure
- **THEN** runtime refresh returns a typed failed outcome preserving provider failure kind and message without exposing concrete HTTP, network, parser package, UI, seasonal, BT, online-rule, diagnostics, or native-player exceptions
