## ADDED Requirements

### Requirement: Capability matrix SHALL gate video enhancement components explicitly
The playback capability matrix SHALL expose explicit supported or unsupported statuses and reason strings for video enhancement, HDR tone mapping, deband filtering, and Anime4K-style preset capabilities before UI or pipeline contracts present them as executable actions.

#### Scenario: Enhancement capability is partially unsupported
- **WHEN** the active adapter supports scaler changes but not HDR tone mapping or Anime4K-style presets
- **THEN** the capability matrix reports each unsupported enhancement component with an explicit reason rather than marking the whole advanced playback surface as generally available
