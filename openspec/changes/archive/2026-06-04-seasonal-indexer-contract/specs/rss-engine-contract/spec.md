## MODIFIED Requirements

### Requirement: RSS engine SHALL remain source-neutral
The system SHALL keep source-specific consumers such as YucWiki seasonal indexing outside the core RSS engine contract while exposing update data that Domain consumers can subscribe to.

#### Scenario: A seasonal feed source is registered
- **WHEN** a YucWiki or other seasonal source is modeled as a feed source
- **THEN** it is refreshed through normal RSS engine contracts before any seasonal consumer-specific normalization occurs

## ADDED Requirements

### Requirement: RSS engine SHALL support downstream seasonal consumers
The system SHALL expose accepted feed items through Domain-facing results or update streams so seasonal consumers can process new items without coupling to concrete feed providers.

#### Scenario: RSS refresh accepts seasonal items
- **WHEN** an RSS refresh accepts new items for a seasonal source
- **THEN** the seasonal indexer can consume those items from the Domain RSS surface without invoking the fetcher or parser directly
