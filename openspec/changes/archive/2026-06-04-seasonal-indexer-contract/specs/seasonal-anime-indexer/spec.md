## MODIFIED Requirements

### Requirement: YucWiki SHALL be modeled as a FeedSource
The system SHALL model yuc.wiki seasonal data as a normal RSS `FeedSource` processed by the RSS engine and seasonal consumer pipeline, not as a special scraper.

#### Scenario: YucWiki source is refreshed
- **WHEN** the yuc.wiki RSS source is refreshed
- **THEN** it is fetched, parsed, scheduled, and deduplicated through RSS engine contracts before seasonal normalization occurs

### Requirement: SeasonalAnimeConsumer SHALL normalize feed items
The system SHALL define a `SeasonalAnimeConsumer` that consumes feed items and normalizes them into seasonal catalog entries persisted through Storage contracts.

#### Scenario: Seasonal feed item is consumed
- **WHEN** a seasonal feed item is accepted by the consumer
- **THEN** it is normalized into a seasonal catalog entry suitable for persistence and later matching

### Requirement: Bangumi match queue MUST respect binding priority
The system MUST define a Bangumi match queue for seasonal catalog entries that never overrides user-confirmed Bangumi bindings and records skipped automatic outcomes when such bindings exist.

#### Scenario: Automatic match candidate conflicts with user binding
- **WHEN** a match queue candidate conflicts with a user-confirmed binding
- **THEN** the user-confirmed binding remains authoritative and the automatic candidate is treated as lower priority
