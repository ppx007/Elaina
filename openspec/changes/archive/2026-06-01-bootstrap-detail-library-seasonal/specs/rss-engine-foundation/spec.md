## ADDED Requirements

### Requirement: RSS engine SHALL define source, fetcher, parser, and scheduler contracts
The system SHALL define reusable `FeedSource`, `FeedFetcher`, `FeedParser`, and `FeedScheduler` contracts for RSS and Atom feeds.

#### Scenario: Feed source is scheduled
- **WHEN** a feed source is due for refresh
- **THEN** the scheduler invokes fetch and parse contracts without source-specific scraping logic

### Requirement: Feed items SHALL have stable deduplication keys
The system SHALL define feed item deduplication contracts using stable keys derived from feed item identity.

#### Scenario: Same feed item appears twice
- **WHEN** a feed item with the same stable dedupe key appears in multiple fetches
- **THEN** the engine treats it as an existing item rather than a new entry

### Requirement: Feed network access MUST use gateway policy
Feed network access MUST use provider/gateway policy for retries, caching, and normalized failures rather than source-specific transport logic.

#### Scenario: Feed fetch fails transiently
- **WHEN** a feed request fails with a retryable condition
- **THEN** the failure is represented through gateway-normalized semantics
