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
The system SHALL keep source-specific consumers such as YucWiki seasonal indexing outside the core RSS engine contract.

#### Scenario: A seasonal feed source is registered
- **WHEN** a YucWiki or other seasonal source is modeled as a feed source
- **THEN** it is refreshed through normal RSS engine contracts before any seasonal consumer-specific normalization occurs

