## MODIFIED Requirements

### Requirement: RSS engine runtime SHALL expose source registry snapshots
The runtime SHALL expose immutable snapshots of registered feed sources, latest
refresh outcomes, accepted update counts, persisted accepted items, known
cursor metadata, and lifecycle state from existing RSS feed store and engine
contracts.

#### Scenario: Source registry changes
- **WHEN** a feed source is registered, removed, listed, or refreshed through
  runtime actions
- **THEN** runtime snapshots reflect the source registry and persisted accepted
  items without requiring Flutter widgets, concrete storage implementations,
  yuc.wiki-specific logic, or platform background services
