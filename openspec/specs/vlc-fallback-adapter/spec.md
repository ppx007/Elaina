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

### Requirement: VLC fallback adapter runtime SHALL wrap strategy with acceptance layer
The system SHALL ensure that the fallback adapter strategy is accessed through a runtime acceptance layer that gates operations, projects combined in-memory and stored state, and publishes cache invalidation events on state transitions.

#### Scenario: Runtime wraps strategy operations
- **WHEN** UI or domain surfaces need fallback state
- **THEN** they observe it through `FallbackAdapterRuntime` which gates by disposed/unavailable/missing scope/unsupported capability

### Requirement: VLC fallback adapter runtime SHALL project fallback state after selection
The system SHALL expose the selected fallback candidate, hidden capabilities, strategy state, and active configuration through a runtime projection that combines in-memory latest outcomes with stored records.

#### Scenario: Projection shows selection result
- **WHEN** a fallback selection completes successfully
- **THEN** the runtime projection exposes the selected candidate ID, hidden capabilities, strategy state kind, and active configuration

### Requirement: Concrete VLC fallback adapter SHALL remain backend-injected
The concrete VLC fallback adapter SHALL implement `PlayerAdapter` inside the
Playback layer while executing player operations only through a Playback-owned
backend interface or backend factory.

#### Scenario: Local file fallback is executed
- **WHEN** a registered VLC fallback candidate is selected for a local file
  source and then receives load, play, pause, seek, stop, or dispose commands
- **THEN** the adapter delegates those operations through the injected backend
  and returns normalized playback command results without exposing VLC package,
  FFI, platform channel, or UI types outside the Playback implementation file

#### Scenario: VLC backend is unavailable
- **WHEN** no verified VLC backend is supplied to the concrete fallback adapter
- **THEN** executable playback commands return normalized adapter-unavailable
  failures rather than claiming native VLC playback support

### Requirement: Concrete VLC fallback adapter SHALL declare only verified capabilities
The concrete VLC fallback adapter SHALL expose a capability matrix that supports
fallback selection and local-file transport commands only when a backend is
available, and SHALL mark unverified advanced, network, subtitle, danmaku, and
track capabilities unsupported with explicit reasons.

#### Scenario: Fallback hides advanced capabilities
- **WHEN** fallback selection chooses the VLC candidate after a compatible
  primary adapter failure
- **THEN** the fallback selection reports hidden capabilities for unsupported
  advanced playback features so UI-owned code can remain capability-driven

### Requirement: Concrete VLC fallback adapter SHALL normalize source and lifecycle failures
The concrete VLC fallback adapter SHALL reject unsupported source kinds,
disposed lifecycle state, and backend operation errors through existing
`PlaybackCommandResult` and `PlaybackFailure` values.

#### Scenario: Unsupported stream source is requested
- **WHEN** HTTP or HLS playback is not declared by the VLC fallback capability
  matrix and the adapter receives that source
- **THEN** load returns a normalized unsupported failure without delegating to
  the backend

#### Scenario: Backend operation fails
- **WHEN** the injected backend throws while executing a supported operation
- **THEN** the adapter returns a normalized operation-failed playback result
  without leaking the backend exception type across layer boundaries

### Requirement: Concrete VLC fallback imports SHALL remain Playback-owned
Concrete VLC fallback implementation details SHALL be restricted to approved
Playback implementation files and tests.

#### Scenario: Boundary checker scans VLC fallback imports
- **WHEN** advanced playback validation scans source files
- **THEN** VLC fallback binding terms and future concrete VLC package imports are
  accepted only in approved Playback implementation files and rejected from UI,
  Domain, Provider, Storage, Streaming, Network, Foundation, and neutral runtime
  files

