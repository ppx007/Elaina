## ADDED Requirements

### Requirement: RSS engine contract SHALL expose accepted feed items for automation consumers
The RSS engine contract SHALL expose accepted feed items through Domain-facing results or update streams so RSS auto-download policies can evaluate already parsed and deduplicated feed items without owning feed fetching, parsing, scheduling, or source-specific scraping.

#### Scenario: RSS automation consumes feed updates
- **WHEN** an RSS refresh accepts new feed items
- **THEN** RSS auto-download policy evaluation consumes those Domain feed items after RSS Engine deduplication rather than invoking fetchers or parsers directly
