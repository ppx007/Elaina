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

### Requirement: RSS auto-download policy SHALL use typed evaluation contracts
The system SHALL represent policy registration, item evaluation, candidate acceptance, candidate rejection, deduplication, disablement, and enqueue handoff through typed outcomes and failures rather than nullable candidates or concrete download adapter exceptions.

#### Scenario: Policy rejects an item
- **WHEN** a feed item fails include/exclude matching or is already handled by policy history
- **THEN** RSS auto-download returns a typed rejection or deduplication outcome with the policy identity and reason

### Requirement: RSS auto-download policy SHALL preserve optional automation behavior
The system SHALL allow RSS refresh, media-library browsing, manual BT task creation, and local playback to continue when RSS auto-download is disabled, unsupported, or has no matching policy.

#### Scenario: Automation is disabled
- **WHEN** RSS auto-download policy evaluation is disabled for the feed scope
- **THEN** the evaluator reports a disabled automation outcome and does not request BT task creation

### Requirement: RSS auto-download policy SHALL report BT handoff state explicitly
The system SHALL persist and expose enqueue handoff state for accepted RSS candidates, including pending, accepted, rejected, duplicate, and adapter-unavailable outcomes with reason strings.

#### Scenario: BT handoff cannot proceed
- **WHEN** a candidate is accepted but BT task creation is unavailable or rejected by capability gating
- **THEN** RSS auto-download records the enqueue outcome and keeps the candidate history available for later inspection without calling concrete torrent engine APIs

### Requirement: RSS auto-download policy SHALL support runtime acceptance layer
The system SHALL allow policy evaluation to be consumed through a runtime facade that provides storage-backed projections, typed scoped outcomes, restart replay, and dispose/unavailable/capability gates instead of calling the deterministic evaluator directly from UI or application flows.

#### Scenario: Runtime wraps evaluator with storage and projections
- **WHEN** the Step 26 runtime acceptance layer is implemented
- **THEN** policy evaluation is consumed through RssAutoDownloadPolicyRuntime.evaluate() which delegates to the deterministic evaluator, persists results to RssAutoDownloadPolicyStore, and returns a typed projection

### Requirement: RSS auto-download policy decisions SHALL propagate through invalidation bus
The system SHALL propagate RSS auto-download policy evaluation decisions (feed item evaluated, candidate accepted, candidate rejected, dedupe state changed, enqueue outcome recorded, policy changed) through the CacheInvalidationBus accepted at bootstrap construction so downstream consumers can refresh derived state.

#### Scenario: Runtime publishes evaluation events
- **WHEN** an evaluation is processed through the runtime for a supported scope
- **THEN** RssAutoDownloadFeedItemEvaluated and appropriate candidate events are published to the cache invalidation bus

