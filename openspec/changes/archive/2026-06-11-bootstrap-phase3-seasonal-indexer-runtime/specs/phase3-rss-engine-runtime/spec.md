## ADDED Requirements

### Requirement: RSS engine runtime SHALL isolate downstream seasonal consumers
RSS engine runtime SHALL expose accepted feed updates that downstream seasonal consumers can observe without making RSS source registration, fetch, parse, dedupe, cursor, refresh, or lifecycle behavior depend on seasonal indexing, YucWiki-specific logic, Bangumi matching, RSS auto-download, BT, online-rule, diagnostics, UI, or native-player behavior.

#### Scenario: Seasonal consumer observes accepted update
- **WHEN** RSS runtime emits an accepted feed item for a registered seasonal feed source
- **THEN** seasonal indexer runtime can consume the item downstream without changing RSS runtime snapshots, source neutrality, fetch semantics, parser behavior, dedupe behavior, or refresh outcomes

### Requirement: RSS engine runtime MUST NOT own seasonal failure semantics
RSS engine runtime MUST NOT convert seasonal consumer, catalog persistence, Bangumi match queue, automatic binding, or seasonal catalog failures into RSS refresh failures.

#### Scenario: Seasonal indexing fails after RSS refresh
- **WHEN** RSS runtime successfully accepts and emits a feed item but downstream seasonal indexing fails
- **THEN** RSS refresh remains successful and the seasonal runtime reports its own typed failure independently
