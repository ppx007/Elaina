## ADDED Requirements

### Requirement: Playback page surface SHALL project concrete local-file capabilities without backend knowledge
The playback page surface contract SHALL project the concrete local-file
runtime capabilities into framework-neutral control descriptors without
requiring UI code to know about media_kit, libmpv, bundled DLL resolution, or
native player backend details.

#### Scenario: Local-file runtime surface is resolved
- **WHEN** the playback page contract resolves a surface for a runtime created
  from the media_kit local-file composition
- **THEN** the surface exposes active play/pause, seek, and stop controls while
  omitting progress, track, secondary panel, advanced playback, provider,
  streaming, and fallback controls that are not declared by the capability
  matrix
