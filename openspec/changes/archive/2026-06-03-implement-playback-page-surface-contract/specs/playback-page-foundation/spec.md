## ADDED Requirements

### Requirement: Playback page foundation SHALL consume UI surface descriptors
The playback page foundation SHALL consume a UI-owned playback page surface contract that maps Domain playback surface state into renderable control and panel descriptors.

#### Scenario: Playback page foundation consumes surface model
- **WHEN** playback page foundation logic needs controls or panels
- **THEN** it consumes UI surface descriptors instead of importing concrete MPV, native player, provider, streaming, or Playback implementation details directly

### Requirement: Domain and Playback MUST NOT import playback page surface contracts
Domain and Playback layers MUST NOT import UI playback page surface contract types or presentation descriptors.

#### Scenario: Layer dependency is checked
- **WHEN** automation scans Domain and Playback Dart files
- **THEN** no import points from those layers into `lib/src/ui` are present
