## ADDED Requirements

### Requirement: Subtitle provider runtime SHALL participate in the ACG smoke gate
The subtitle provider runtime SHALL be consumable by a non-UI ACG experience
smoke gate through existing discovery, cache, and parser handoff surfaces.

#### Scenario: ACG smoke gate resolves provider subtitles
- **WHEN** the ACG smoke gate is given a subtitle provider query
- **THEN** it discovers provider candidates, reuses non-expired subtitle cache
  records on equivalent requests, loads the selected candidate through
  `PlaybackMetadataBridge`, and reports typed provider failures without
  concrete OpenSubtitles transport leakage
