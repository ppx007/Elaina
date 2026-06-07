## ADDED Requirements

### Requirement: Capability matrix SHALL gate fallback adapter behavior explicitly
The playback capability matrix SHALL expose explicit supported or unsupported status and reason strings for fallback adapter behavior before playback contracts treat secondary adapter selection as executable.

#### Scenario: Fallback adapter is unsupported
- **WHEN** no fallback adapter is registered, enabled, or compatible with the current source
- **THEN** the capability matrix reports fallback adapter support as unsupported with an explicit reason instead of allowing fallback to appear executable

### Requirement: Capability matrix SHALL expose hidden fallback capabilities
The playback capability matrix SHALL preserve unsupported statuses and reason strings for capabilities hidden by the selected fallback adapter.

#### Scenario: Fallback adapter hides advanced features
- **WHEN** playback switches to a fallback adapter that lacks advanced caption, danmaku, enhancement, or track capabilities
- **THEN** the capability matrix reports those capabilities as unsupported so UI can hide or disable them without fallback-specific branches
