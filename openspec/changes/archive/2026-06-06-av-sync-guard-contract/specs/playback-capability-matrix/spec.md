## ADDED Requirements

### Requirement: Capability matrix SHALL gate AV sync guard behavior explicitly
The playback capability matrix SHALL expose explicit supported or unsupported status and reason strings for AVSyncGuard before playback contracts rely on automatic drift degradation behavior.

#### Scenario: AV sync guard is unsupported
- **WHEN** the active adapter or platform cannot provide normalized sync samples or support deterministic degradation decisions
- **THEN** the capability matrix reports `avSyncGuard` as unsupported with an explicit reason rather than allowing automatic degradation to appear executable
