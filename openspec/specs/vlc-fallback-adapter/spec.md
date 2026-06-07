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

### Requirement: Fallback adapter SHALL use typed selection contracts
The system SHALL represent fallback registration, evaluation, selection, disablement, and rejection through typed outcomes and failures rather than nullable fallback selections.

#### Scenario: Fallback is rejected
- **WHEN** a primary adapter failure is not compatible with fallback or no candidate supports the requested source
- **THEN** the fallback strategy returns a typed failure with a reason instead of returning `null` without explanation

### Requirement: Fallback adapter SHALL preserve optional secondary adapter behavior
The system SHALL allow playback to surface the original normalized failure when no fallback adapter is enabled, registered, or compatible.

#### Scenario: Fallback is disabled
- **WHEN** fallback selection is disabled for the current playback scope
- **THEN** the fallback strategy reports a disabled fallback outcome and core playback does not require VLC availability

### Requirement: Fallback adapter SHALL report hidden capability differences
The system SHALL include unsupported fallback capabilities and reason strings in fallback selection results whenever a secondary adapter cannot provide features exposed by the primary adapter.

#### Scenario: Selected fallback hides capabilities
- **WHEN** a fallback candidate is selected with fewer capabilities than the primary adapter
- **THEN** the selection reports hidden capabilities so UI and Domain surfaces can remain capability-driven

