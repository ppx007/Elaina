## ADDED Requirements

### Requirement: Concrete MPV binding SHALL apply advanced subtitle intent
The concrete MPV binding SHALL map Playback-owned advanced subtitle requests
into MPV property and command calls without exposing media_kit, libmpv, native
handles, subtitle renderer widgets, GPU renderers, or platform channels outside
the Playback layer.

#### Scenario: Dual subtitles are applied
- **WHEN** a primary and secondary subtitle source are selected in ordered form
- **THEN** the concrete bridge applies a deterministic MPV plan that loads the
  primary subtitle and assigns the secondary subtitle role without exposing
  concrete player details to UI or Domain code

#### Scenario: ASS subtitle enhancement is applied
- **WHEN** an ASS enhancement request reaches the concrete bridge
- **THEN** the bridge enables MPV ASS handling and loads the subtitle source
  through normalized command data

#### Scenario: PGS subtitle rendering is applied
- **WHEN** a PGS subtitle request reaches the concrete bridge
- **THEN** the bridge loads the subtitle source through normalized MPV command
  data instead of implementing a custom image subtitle renderer

#### Scenario: Advanced subtitle application fails
- **WHEN** the concrete backend rejects an MPV property or command
- **THEN** the bridge returns a typed advanced caption failure rather than
  leaking media_kit, libmpv, native, or platform exceptions

### Requirement: Concrete MPV subtitle imports SHALL remain Playback-owned
Concrete subtitle renderer integration SHALL remain restricted to approved
Playback binding implementation and tests.

#### Scenario: Boundary checker scans subtitle renderer imports
- **WHEN** advanced caption validation scans source files
- **THEN** concrete player imports and MPV subtitle command bindings are
  accepted only in approved Playback implementation files and rejected from UI,
  Domain, Provider, Storage, Streaming, Network, Foundation, and deterministic
  runtime files
