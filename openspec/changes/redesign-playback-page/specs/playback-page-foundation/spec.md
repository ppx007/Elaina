## MODIFIED Requirements

### Requirement: Playback page SHALL stay capability-driven
The playback page SHALL render controls, overlays, track inspector state,
buffering/failure state, and capability status only from Domain/Playback
contracts and UI-owned playback page descriptors.

#### Scenario: Playback page initializes
- **WHEN** the playback page opens for a supported source
- **THEN** it renders only controls and entry points allowed by the current
  capability matrix
- **AND** renders read-only overlay and capability state that is present in the
  playback snapshot or matrix

### Requirement: Playback page MUST NOT include later-phase integrations
The playback page foundation MUST NOT require provider metadata, Bangumi,
Dandanplay, RSS, BT download task mutation, online source parsing, diagnostics
center UI, or concrete native player integrations to render the production
playback page.

#### Scenario: Local file playback is available
- **WHEN** a local file can be played through the active adapter
- **THEN** playback can proceed and the page can render using playback
  contracts alone

### Requirement: Advanced actions SHALL be secondary panel entry points only
The playback page SHALL expose advanced playback features as read-only
capability/status entries unless a dedicated playback page intent and runtime
command are available.

#### Scenario: Advanced feature has no executable page command
- **WHEN** video enhancement, AV sync, advanced captions, or fallback state is
  supported by contracts but not exposed as a playback page command
- **THEN** the playback page does not expose it as an active command button
