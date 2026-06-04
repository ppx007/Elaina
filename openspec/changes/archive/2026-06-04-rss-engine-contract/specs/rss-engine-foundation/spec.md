## MODIFIED Requirements

### Requirement: RSS engine SHALL define source, fetcher, parser, and scheduler contracts
The system SHALL define reusable `FeedSource`, `FeedFetcher`, `FeedParser`, and `FeedScheduler` contracts for RSS and Atom feeds, and Domain RSS orchestration SHALL compose those contracts into a refresh pipeline without source-specific scraping logic.

#### Scenario: Feed source is scheduled
- **WHEN** a feed source is due for refresh
- **THEN** the scheduler invokes fetch and parse contracts without source-specific scraping logic

### Requirement: Feed items SHALL have stable deduplication keys
The system SHALL define feed item deduplication contracts using stable keys derived from feed item identity, and accepted dedupe keys SHALL be persistable through Storage-layer feed state.

#### Scenario: Same feed item appears twice
- **WHEN** a feed item with the same stable dedupe key appears in multiple fetches
- **THEN** the engine treats it as an existing item rather than a new entry

### Requirement: Feed network access MUST use gateway policy
Feed network access MUST use provider/gateway policy for retries, caching, cache validators, and normalized failures rather than source-specific transport logic.

#### Scenario: Feed fetch fails transiently
- **WHEN** a feed request fails with a retryable condition
- **THEN** the failure is represented through gateway-normalized semantics

## ADDED Requirements

### Requirement: RSS engine SHALL expose Domain refresh results
The system SHALL expose Domain-facing refresh results that identify the feed source, newly accepted items, warnings, and provider-normalized failure information.

#### Scenario: Feed refresh has new items
- **WHEN** a feed refresh accepts new items after parsing and deduplication
- **THEN** Domain receives a typed refresh result and update stream without depending on concrete provider classes
