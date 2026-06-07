## ADDED Requirements

### Requirement: BT task core contract SHALL accept engine-neutral RSS automation handoffs
The BT task core contract SHALL define an engine-neutral task creation handoff surface that RSS auto-download can target with accepted candidate metadata, policy identity, source URI, and dedupe key without importing concrete torrent engine APIs.

#### Scenario: RSS candidate requests BT task creation
- **WHEN** RSS auto-download accepts a magnet or torrent candidate
- **THEN** BT task core receives an engine-neutral task creation request through Domain or Streaming contracts rather than a concrete torrent engine call
