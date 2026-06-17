## ADDED Requirements

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
