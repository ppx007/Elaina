## ADDED Requirements

### Requirement: Seasonal indexer contracts SHALL expose runtime-facing action outcomes
Seasonal indexer contracts SHALL provide runtime-facing action/result semantics for registering seasonal feed sources, consuming RSS updates, listing catalog entries, projecting queue items, processing match work, observing catalog updates, and disposal.

#### Scenario: Runtime action completes
- **WHEN** a seasonal runtime action succeeds, is unavailable, is ignored, fails, or is invoked after disposal
- **THEN** callers receive a normalized Domain seasonal outcome rather than inferring behavior from thrown RSS, consumer, storage, provider, binding, stream, UI, network, or native exceptions

### Requirement: Seasonal indexer contracts SHALL persist runtime catalog state
Seasonal indexer contracts SHALL preserve normalized catalog entries and source item identity through storage-backed records so runtime snapshots and duplicate suppression survive restart-like store reuse.

#### Scenario: Existing source item is consumed again
- **WHEN** runtime consumes an RSS feed item whose seasonal source item was already persisted
- **THEN** seasonal catalog contracts identify the existing source item and avoid storing or emitting a duplicate catalog entry

### Requirement: Seasonal indexer contracts SHALL expose match queue projections
Seasonal indexer contracts SHALL expose pending count, next item, candidate, status, failure, skipped, and applied match queue projections needed by runtime checks without requiring concrete provider transport or background worker infrastructure.

#### Scenario: Match queue is projected
- **WHEN** runtime asks for current match queue state
- **THEN** contracts return deterministic queue records and candidate state without dispatching Bangumi provider searches unless explicit match processing is requested

### Requirement: Seasonal indexer contracts MUST preserve user binding authority
Seasonal indexer contracts MUST preserve user-confirmed provider binding authority across automatic candidate application and skipped match queue outcomes.

#### Scenario: User-confirmed binding exists
- **WHEN** automatic match application is requested for a catalog entry with a user-confirmed binding
- **THEN** contracts skip the automatic binding, retain the user-confirmed binding, and expose the skipped outcome to the runtime
