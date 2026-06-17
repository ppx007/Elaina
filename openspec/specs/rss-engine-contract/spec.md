# rss-engine-contract Specification

## Purpose
TBD - created by archiving change rss-engine-contract. Update Purpose after archive.
## Requirements
### Requirement: RSS engine SHALL persist feed refresh state
The system SHALL define Storage-backed feed source, feed item, fetch cursor, and deduplication state used by RSS and Atom refresh flows.

#### Scenario: Feed refresh state survives restart
- **WHEN** a feed source has been refreshed and feed items have been accepted
- **THEN** later refreshes can load the source cursor, known dedupe keys, and persisted items through Storage contracts

### Requirement: RSS engine SHALL orchestrate fetch parse dedupe and persist steps
The system SHALL define a Domain-facing RSS engine contract that composes feed scheduling, gateway-backed fetching, parser handoff, deduplication, persistence, and update emission without exposing concrete provider implementations to UI or seasonal consumers.

#### Scenario: Feed source refresh completes
- **WHEN** Domain refreshes a due RSS or Atom feed source
- **THEN** the engine fetches through `FeedFetcher`, parses through `FeedParser`, retains new items through deduplication, persists accepted items, and emits only new updates

### Requirement: RSS engine SHALL preserve conditional fetch metadata
The system SHALL preserve ETag and last-modified metadata from feed fetch responses and include them in future feed fetch requests for the same source.

#### Scenario: Feed source is refreshed repeatedly
- **WHEN** a previous feed fetch returned ETag or last-modified metadata
- **THEN** the next fetch request for the same feed source includes those validators without the fetcher owning durable state

### Requirement: RSS engine SHALL remain source-neutral
The system SHALL keep source-specific consumers such as YucWiki seasonal indexing outside the core RSS engine contract while exposing update data that Domain consumers can subscribe to.

#### Scenario: A seasonal feed source is registered
- **WHEN** a YucWiki or other seasonal source is modeled as a feed source
- **THEN** it is refreshed through normal RSS engine contracts before any seasonal consumer-specific normalization occurs

### Requirement: RSS engine SHALL support downstream seasonal consumers
The system SHALL expose accepted feed items through Domain-facing results or update streams so seasonal consumers can process new items without coupling to concrete feed providers.

#### Scenario: RSS refresh accepts seasonal items
- **WHEN** an RSS refresh accepts new items for a seasonal source
- **THEN** the seasonal indexer can consume those items from the Domain RSS surface without invoking the fetcher or parser directly

### Requirement: RSS engine contract SHALL expose accepted feed items for automation consumers
The RSS engine contract SHALL expose accepted feed items through Domain-facing results or update streams so RSS auto-download policies can evaluate already parsed and deduplicated feed items without owning feed fetching, parsing, scheduling, or source-specific scraping.

#### Scenario: RSS automation consumes feed updates
- **WHEN** an RSS refresh accepts new feed items
- **THEN** RSS auto-download policy evaluation consumes those Domain feed items after RSS Engine deduplication rather than invoking fetchers or parsers directly

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

### Requirement: Feed fetch responses SHALL support not-modified refreshes
Feed fetch responses SHALL represent HTTP not-modified outcomes so RSS runtime
refresh can update cursor freshness without invoking feed parsers or emitting
new items.

#### Scenario: Feed source is not modified
- **WHEN** a concrete feed fetcher receives a not-modified response for a
  request with ETag or Last-Modified validators
- **THEN** the RSS engine returns a successful refresh with no accepted items,
  preserves cursor metadata, and does not call `FeedParser`

### Requirement: Concrete parser failures SHALL become typed RSS refresh failures
RSS engine refresh SHALL normalize concrete parser failures into typed refresh
and runtime failures instead of leaking raw XML/parser exceptions.

#### Scenario: Concrete parser rejects malformed XML
- **WHEN** a concrete RSS or Atom parser reports a malformed feed through
  provider-normalized failure semantics
- **THEN** runtime refresh returns a typed parser failure preserving the
  failure message without exposing parser package exceptions to UI or
  downstream consumers

