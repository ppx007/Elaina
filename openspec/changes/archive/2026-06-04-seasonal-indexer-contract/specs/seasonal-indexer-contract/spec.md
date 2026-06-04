## ADDED Requirements

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
The system SHALL apply automatic Bangumi matches only through binding contracts that preserve user-confirmed binding priority.

#### Scenario: Automatic candidate conflicts with user binding
- **WHEN** the match worker finds an automatic candidate for an entry with an existing user-confirmed binding
- **THEN** the automatic match is skipped and the user-confirmed binding remains authoritative
