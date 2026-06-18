## ADDED Requirements

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
