## ADDED Requirements

### Requirement: UI-owned app shell SHALL consume playback composition through contracts
Core runtime changes SHALL expose stable Domain/Playback contracts for the app
composition root when UI ownership is assigned to an external implementation
track, but MUST NOT implement app shell, routes, pages, file picker UX, video
surfaces, or Flutter widgets.

#### Scenario: External UI model wires local playback
- **WHEN** the external UI app shell needs local file playback
- **THEN** it may create the Playback-owned media_kit/libmpv composition
  descriptor and pass it to the Domain player-core bootstrap, but it MUST NOT
  import `package:media_kit`, concrete libmpv types, VLC, provider clients,
  storage internals, streaming engines, or network implementations directly

#### Scenario: Boundary checker scans UI entry points
- **WHEN** player-core validation scans `lib/src/ui/**` and `lib/main.dart`
- **THEN** concrete player package imports and concrete native player
  dependencies are rejected from UI-owned files
