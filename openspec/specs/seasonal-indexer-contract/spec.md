# seasonal-indexer-contract Specification

## Purpose
TBD - created by archiving change seasonal-indexer-contract. Update Purpose after archive.
## Requirements
### Requirement: Seasonal indexer SHALL persist normalized catalog entries
The system SHALL define Storage-backed seasonal catalog contracts for entries produced by seasonal feed consumers.

#### Scenario: Seasonal feed item is normalized
- **WHEN** a seasonal consumer accepts a feed item and emits a seasonal catalog entry
- **THEN** the entry is persisted through Storage contracts with season, source item, title, summary, publication, and source URI metadata

### Requirement: Seasonal indexer SHALL orchestrate RSS updates into seasonal consumers
The system SHALL define a Domain seasonal indexer contract that consumes RSS engine updates, maps accepted feed items into seasonal source items, and invokes matching `SeasonalAnimeConsumer` instances without adding source-specific logic to the RSS engine.

#### Scenario: RSS engine emits a seasonal item
- **WHEN** the RSS engine publishes a feed item from a registered seasonal feed source
- **THEN** the seasonal indexer dispatches it to the matching consumer and stores the normalized catalog entries

### Requirement: Seasonal indexer SHALL enqueue Bangumi match work
The system SHALL enqueue normalized seasonal catalog entries for Bangumi matching with durable queue state and candidate records.

#### Scenario: Seasonal catalog entry is stored
- **WHEN** a seasonal catalog entry has no authoritative user-confirmed Bangumi binding
- **THEN** the entry is added to the Bangumi match queue for provider-governed subject search

### Requirement: Seasonal indexer SHALL apply automatic matches without overriding user bindings
The system SHALL apply automatic Bangumi matches only through binding contracts
that preserve user-confirmed binding priority. The default automatic match
minimum confidence SHALL be named and shared across queue, worker, and runtime
bootstrap entry points rather than repeated as an inline literal.

#### Scenario: Automatic candidate conflicts with user binding
- **WHEN** the match worker finds an automatic candidate for an entry with an
  existing user-confirmed binding
- **THEN** the automatic match is skipped and the user-confirmed binding remains
  authoritative

#### Scenario: Automatic confidence default is reused
- **WHEN** queue, worker, or runtime bootstrap code constructs automatic Bangumi
  matching with the default confidence threshold
- **THEN** it references the named default threshold rather than duplicating a
  numeric literal

### Requirement: Seasonal indexer contracts SHALL expose runtime-facing action outcomes
Seasonal indexer contracts SHALL provide runtime-facing action/result semantics for registering seasonal feed sources, consuming RSS updates, listing catalog entries, projecting queue items, processing match work, observing catalog updates, and disposal.

#### Scenario: Runtime action completes
- **WHEN** a seasonal runtime action succeeds, is unavailable, is ignored, fails, or is invoked after disposal
- **THEN** callers receive a normalized Domain seasonal outcome rather than inferring behavior from thrown RSS, consumer, storage, provider, binding, stream, UI, network, or native exceptions

### Requirement: Seasonal indexer contracts SHALL persist runtime catalog state
Seasonal indexer contracts SHALL preserve normalized catalog entries and source item identity through storage-backed records so runtime snapshots and duplicate suppression survive restart-like store reuse.

#### Scenario: Existing source item is consumed again
- **WHEN** runtime consumes an RSS feed item whose seasonal source item was already persisted
- **THEN** seasonal catalog contracts identify the existing source item and avoid storing or emitting a duplicate catalog entry

### Requirement: Seasonal indexer contracts SHALL expose match queue projections
Seasonal indexer contracts SHALL expose pending count, next item, candidate, status, failure, skipped, and applied match queue projections needed by runtime checks without requiring concrete provider transport or background worker infrastructure.

#### Scenario: Match queue is projected
- **WHEN** runtime asks for current match queue state
- **THEN** contracts return deterministic queue records and candidate state without dispatching Bangumi provider searches unless explicit match processing is requested

### Requirement: Seasonal indexer contracts MUST preserve user binding authority
Seasonal indexer contracts MUST preserve user-confirmed provider binding authority across automatic candidate application and skipped match queue outcomes.

#### Scenario: User-confirmed binding exists
- **WHEN** automatic match application is requested for a catalog entry with a user-confirmed binding
- **THEN** contracts skip the automatic binding, retain the user-confirmed binding, and expose the skipped outcome to the runtime

### Requirement: Seasonal consumer SHALL support source-neutral FeedItem projection
The seasonal indexer contracts SHALL include a reusable consumer that maps
accepted `FeedItem` values into seasonal catalog entries for an explicitly
configured source id and season.

#### Scenario: Feed item is projected to seasonal catalog entry
- **WHEN** the configured consumer receives an accepted feed item for its source
- **THEN** it emits a `SeasonalCatalogEntry` preserving title, summary, link,
  publication time, source identity, and configured season without parsing
  source-specific HTML or scraper formats

### Requirement: Seasonal catalog ids SHALL use named defaults
Seasonal feed item projection SHALL derive catalog ids from a named default
prefix or caller-supplied prefix instead of repeating inline string literals.

#### Scenario: Consumer derives catalog id
- **WHEN** a feed item is projected by the default consumer
- **THEN** the catalog id is derived from the named prefix and feed item id,
  keeping the prefix reusable across tests, runtime checks, and app composition

