## ADDED Requirements

### Requirement: Seasonal runtime SHALL expose a deterministic feed flow
The seasonal runtime SHALL provide a non-UI flow that composes RSS refreshes
with seasonal item consumption and Bangumi queue projection.

#### Scenario: Seasonal feed source is refreshed through the flow
- **WHEN** a registered seasonal feed source is refreshed through the flow
- **THEN** accepted RSS refresh items are consumed by matching
  `SeasonalAnimeConsumer` instances, newly normalized catalog entries are
  persisted, Bangumi match queue work is projected, and the operation returns an
  immutable typed refresh snapshot without relying on asynchronous stream
  listener timing

### Requirement: Seasonal runtime SHALL keep not-modified refreshes side-effect light
The seasonal feed flow SHALL treat RSS not-modified refreshes as successful
refreshes with no new seasonal catalog entries.

#### Scenario: Feed is not modified
- **WHEN** RSS refresh returns no accepted items because the feed was not
  modified
- **THEN** the flow returns success, leaves existing catalog and match queue
  state intact, and does not call seasonal consumers

### Requirement: Seasonal feed flow SHALL normalize lifecycle failures
Seasonal feed flow actions SHALL return typed outcomes for source registration,
refresh, and disposal instead of leaking raw RSS, seasonal, storage, or stream
exceptions.

#### Scenario: Flow is disposed
- **WHEN** source registration or refresh is requested after disposal
- **THEN** the flow returns a disposed outcome without invoking RSS refresh or
  seasonal consumption
