## ADDED Requirements

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
