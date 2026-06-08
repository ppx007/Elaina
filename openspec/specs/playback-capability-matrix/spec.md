# playback-capability-matrix Specification

## Purpose
TBD - created by archiving change bootstrap-player-core. Update Purpose after archive.
## Requirements
### Requirement: Playback capabilities SHALL be adapter and platform scoped
The system SHALL define a capability matrix that combines active adapter capabilities with platform capabilities before UI decisions are made.

#### Scenario: Active adapter changes
- **WHEN** the active player adapter or platform target changes
- **THEN** the capability matrix is recalculated before controls or panels are shown

### Requirement: UI SHALL render playback controls from capabilities
The playback UI SHALL show, hide, or disable controls and secondary panel entry points based on the capability matrix.

#### Scenario: Capability is unavailable
- **WHEN** a capability such as track switching or HLS playback is unavailable
- **THEN** the UI does not present it as an executable action

### Requirement: Capability Matrix SHALL support future adapter expansion
The system SHALL allow future VLC, ExoPlayer, AVPlayer, advanced rendering, caption, and fallback adapters to add capability rows without rewriting playback UI contracts.

#### Scenario: A future fallback adapter is added
- **WHEN** a later change adds another player adapter
- **THEN** the adapter declares capabilities through the matrix instead of adding adapter-specific UI branches

#### Scenario: Advanced playback capability is unavailable
- **WHEN** advanced rendering, caption rendering, or fallback behavior is unavailable for the active adapter or platform
- **THEN** the capability matrix reports it as unsupported so UI hides or disables the feature

### Requirement: Capability matrix SHALL drive executable controller surface state
The active playback capability matrix SHALL determine every visible playback control and secondary panel returned by the Domain playback controller surface state.

#### Scenario: Only transport controls are supported
- **WHEN** the active adapter supports play/pause, seek, stop, and progress reporting but not track switching or secondary panels
- **THEN** the controller surface state exposes transport and progress controls only

#### Scenario: Track capabilities are supported
- **WHEN** the active adapter supports audio track switching, subtitle track switching, and secondary panels
- **THEN** the controller surface state exposes audio track controls, subtitle track controls, and the tracks panel entry point

### Requirement: Unsupported capabilities SHALL remain explicit in runtime checks
The runtime slice SHALL preserve explicit unsupported statuses and reasons for capabilities that are not declared by the active adapter.

#### Scenario: Capability is missing from adapter declaration
- **WHEN** runtime code asks for a capability that the active adapter did not declare
- **THEN** the capability matrix reports it as unsupported with a reason instead of treating it as supported by default

### Requirement: Capability matrix SHALL gate AV sync guard behavior explicitly
The playback capability matrix SHALL expose explicit supported or unsupported status and reason strings for AVSyncGuard before playback contracts rely on automatic drift degradation behavior.

#### Scenario: AV sync guard is unsupported
- **WHEN** the active adapter or platform cannot provide normalized sync samples or support deterministic degradation decisions
- **THEN** the capability matrix reports `avSyncGuard` as unsupported with an explicit reason rather than allowing automatic degradation to appear executable

### Requirement: Capability matrix SHALL gate advanced caption features explicitly
The playback capability matrix SHALL expose explicit supported or unsupported status and reason strings for Matrix4 danmaku, dual subtitles, PGS subtitle rendering, and ASS subtitle enhancement before UI or renderer contracts treat those features as executable.

#### Scenario: PGS rendering is unsupported
- **WHEN** the active adapter or platform cannot support PGS subtitle rendering
- **THEN** the capability matrix reports `pgsSubtitleRendering` as unsupported with an explicit reason rather than allowing PGS rendering to appear executable

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

### Requirement: Capability matrix SHALL gate video enhancement components explicitly
The playback capability matrix SHALL expose explicit supported or unsupported statuses and reason strings for video enhancement, HDR tone mapping, deband filtering, and Anime4K-style preset capabilities before UI or pipeline contracts present them as executable actions.

#### Scenario: Enhancement capability is partially unsupported
- **WHEN** the active adapter supports scaler changes but not HDR tone mapping or Anime4K-style presets
- **THEN** the capability matrix reports each unsupported enhancement component with an explicit reason rather than marking the whole advanced playback surface as generally available

### Requirement: Player core runtime SHALL derive capability matrix from active adapter
The player core runtime SHALL derive its playback capability matrix from the active player adapter or deterministic binding declaration rather than hard-coded UI or controller assumptions.

#### Scenario: Active adapter declares unsupported HLS playback
- **WHEN** the active adapter reports HLS playback as unsupported
- **THEN** the runtime capability matrix reports HLS playback as unsupported and controller/page surfaces do not expose HLS playback as executable

### Requirement: Capability matrix SHALL remain stable within runtime snapshots
The player core runtime SHALL expose a stable capability matrix snapshot for controller and page foundation consumers until the active adapter changes or the runtime is rebuilt.

#### Scenario: Controller resolves surface state
- **WHEN** the playback controller resolves visible controls and panels
- **THEN** it reads the runtime capability matrix snapshot rather than recalculating adapter-specific capability rules independently

