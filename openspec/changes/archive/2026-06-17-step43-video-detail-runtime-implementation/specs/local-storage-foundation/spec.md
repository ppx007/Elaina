## ADDED Requirements

### Requirement: Storage foundation SHALL support video-detail runtime composition
The concrete video-detail runtime implementation SHALL consume
`StorageFoundation` through existing media-library, playback-history, and
provider-binding storage contracts rather than through database handles or SQL.

#### Scenario: Detail runtime replays storage state
- **WHEN** media catalog records, playback history records, and provider
  binding records are persisted in storage
- **THEN** a storage-backed video-detail runtime composed with the same storage
  can load detail data after restart while keeping SQLite and SQL details
  inside Foundation/Storage implementation files
