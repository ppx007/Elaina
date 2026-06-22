## MODIFIED Requirements

### Requirement: Playback page surface SHALL expose basic danmaku overlay descriptors
The playback page surface contract SHALL expose plain Dart descriptors for
basic danmaku overlay lanes and comments so production UI can render danmaku
without changing Domain or Playback runtime contracts.

#### Scenario: Surface descriptor maps danmaku state
- **WHEN** Domain playback state contains a basic danmaku overlay snapshot
- **THEN** the playback page surface descriptor exposes framework-neutral
  scrolling, top, and bottom lane data
- **AND** the production playback page may render those descriptors without
  importing concrete renderer implementations or native player bindings

## ADDED Requirements

### Requirement: Playback page driver SHALL project track discovery state
The playback page driver SHALL convert playback track discovery results into a
UI-owned read model that separates idle, loading, loaded, unsupported, and
failed states.

#### Scenario: Track discovery is unsupported
- **WHEN** the active controller reports track discovery as unsupported
- **THEN** the driver projects an unsupported track-panel state with a reason
- **AND** the page does not show executable track choices
