# vlc-fallback-adapter Specification

## Purpose
TBD - created by archiving change bootstrap-advanced-playback-core. Update Purpose after archive.
## Requirements
### Requirement: VLC fallback SHALL be modeled as an adapter fallback strategy
The system SHALL define fallback adapter contracts that can switch from a primary adapter to VLC or another secondary adapter after compatible failures.

#### Scenario: Primary adapter fails to load source
- **WHEN** the primary adapter reports a fallback-compatible load failure
- **THEN** the fallback strategy can select a secondary adapter without UI depending on VLC-specific APIs

### Requirement: Fallback adapter SHALL hide unsupported capabilities
The system SHALL expose capability differences after fallback so UI hides or disables features that the fallback adapter cannot support.

#### Scenario: Fallback adapter lacks danmaku rendering
- **WHEN** playback falls back to an adapter without danmaku capability
- **THEN** the capability matrix reports danmaku rendering as unsupported with a reason

### Requirement: Fallback adapter MUST avoid becoming mandatory playback path
The system MUST keep fallback adapters optional so core playback remains functional without VLC or any secondary engine installed.

#### Scenario: No fallback adapter is available
- **WHEN** the primary adapter fails and no fallback adapter is registered
- **THEN** the failure is surfaced through playback contracts rather than requiring VLC availability

