# rss-auto-download-policy Specification

## Purpose
TBD - created by archiving change bootstrap-automation-extension-core. Update Purpose after archive.
## Requirements
### Requirement: RSS auto-download policies SHALL consume existing feed contracts
The system SHALL define RSS auto-download policies as consumers of existing `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, and feed deduplication contracts rather than as a parallel feed engine.

#### Scenario: Feed refresh is evaluated for automation
- **WHEN** a scheduled feed source produces parsed feed items
- **THEN** RSS auto-download policy evaluates those items after RSS parsing and deduplication without source-specific scraping logic

### Requirement: RSS auto-download policies SHALL support declarative matching
The system SHALL define declarative feed item matchers for title, group, episode, season, resolution, size, category, include terms, exclude terms, regex, glob, and metadata predicates with explicit AND, OR, and negation semantics.

#### Scenario: Matching item satisfies a policy
- **WHEN** a feed item satisfies the policy's declarative matcher expression
- **THEN** the policy emits a download candidate with the matched rule identity and normalized item metadata

#### Scenario: Exclusion matcher wins
- **WHEN** a feed item satisfies both an include matcher and an exclude matcher in the same policy
- **THEN** the policy rejects the item and records the exclusion reason for diagnostics

### Requirement: RSS auto-download SHALL maintain durable history
The system SHALL persist policy evaluation history, accepted item keys, rejected item keys, and enqueue outcomes through Storage-layer contracts so repeated feed refreshes do not enqueue duplicate BT tasks.

#### Scenario: Previously accepted item appears again
- **WHEN** a feed item with an already accepted stable dedupe key appears in a later refresh
- **THEN** RSS auto-download does not enqueue another BT task and reports the item as already handled

### Requirement: RSS auto-download SHALL enqueue through engine-neutral BT contracts
The system SHALL hand accepted candidates to BT task creation through engine-neutral Streaming-layer contracts and MUST NOT call concrete torrent engine APIs directly.

#### Scenario: Candidate is accepted
- **WHEN** RSS auto-download accepts a magnet or torrent candidate
- **THEN** it requests BT task creation through the task adapter boundary with source metadata and policy identity

### Requirement: RSS auto-download MUST remain optional
The system MUST ensure RSS auto-download is capability-gated and never required for local playback, media-library use, manual BT task creation, or core playback startup.

#### Scenario: Automation capability is unavailable
- **WHEN** RSS auto-download is unsupported or disabled on the current environment
- **THEN** local playback, library browsing, and manual BT task flows remain available through their existing contracts

