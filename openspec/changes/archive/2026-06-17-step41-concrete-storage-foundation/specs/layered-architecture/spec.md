## ADDED Requirements

### Requirement: SQLite implementation details MUST stay inside Foundation/Storage
Concrete SQLite imports, handles, SQL statements, schema bootstrap code, and row-mapping logic MUST remain inside Foundation/Storage implementation files, tests, and non-UI smoke tools.

#### Scenario: A non-storage layer needs persisted data
- **WHEN** UI, Domain, Playback, Provider, Streaming, or Network code needs persisted data
- **THEN** it consumes existing storage contracts or runtime projections rather than importing SQLite packages, opening database handles, or issuing SQL directly
