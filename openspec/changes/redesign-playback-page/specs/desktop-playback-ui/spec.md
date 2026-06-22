## MODIFIED Requirements

### Requirement: Playback UI SHALL render from contract surface descriptors
The playback page SHALL render video elements, transport controls, subtitle and
danmaku overlays, track entry points, buffering status, failure status, and
capability status from UI-owned playback descriptors and Domain/Playback
contracts, without referencing concrete playback adapters or native bindings.

#### Scenario: Render transport and overlay state
- **WHEN** the active playback surface exposes play/pause, seek, stop,
  subtitle cue, and danmaku comment descriptors
- **THEN** the playback page renders the executable transport controls
- **AND** renders subtitle cues and danmaku comments as overlay read models
- **AND** hides executable controls for unsupported capabilities

#### Scenario: Render playback failure
- **WHEN** the playback state is failed with a failure reason
- **THEN** the playback page shows the failure reason without exposing native
  adapter or binding exception types

### Requirement: Playback UI controls SHALL dispatch page intents
The playback page controls SHALL translate user actions into
`PlaybackPageIntent` commands and dispatch them through the playback page driver
contract.

#### Scenario: User switches a subtitle track
- **WHEN** the user selects a subtitle track from the playback inspector
- **THEN** the playback page dispatches a `PlaybackPageIntent.selectTrack`
  intent with a Domain-facing subtitle track identifier

## ADDED Requirements

### Requirement: Playback UI SHALL expose a read-only capability inspector
The playback page SHALL expose active playback capability status, including
transport, track, subtitle/danmaku, video enhancement, AV sync guard, advanced
caption, and fallback capability support as read-only UI state unless an
explicit executable command contract exists.

#### Scenario: Advanced capability lacks a page command
- **WHEN** video enhancement or AV sync guard support is visible through the
  capability matrix but no playback page command is declared
- **THEN** the playback page shows support status and reason text
- **AND** does not render a fake executable control
