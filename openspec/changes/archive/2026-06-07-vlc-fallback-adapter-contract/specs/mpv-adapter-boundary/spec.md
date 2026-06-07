## ADDED Requirements

### Requirement: Primary adapter failures SHALL remain normalized for fallback strategy
The system SHALL expose fallback-compatible primary adapter failures through normalized playback failure contracts that fallback strategy can consume without importing MPV, libmpv, VLC, native player, or UI dependencies.

#### Scenario: Primary adapter load failure is fallback-compatible
- **WHEN** the primary adapter cannot load a source for a normalized fallback-compatible reason
- **THEN** fallback strategy receives normalized failure data and the playback source rather than concrete MPV, VLC, native exception, or platform player details
