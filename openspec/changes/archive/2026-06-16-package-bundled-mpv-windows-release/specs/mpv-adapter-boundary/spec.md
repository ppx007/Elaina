## ADDED Requirements

### Requirement: Concrete MPV binding SHALL prefer bundled libmpv for production releases
The concrete MPV binding SHALL support an explicitly supplied or bundled
`libmpv-2.dll` path so Windows release artifacts can run without requiring the
customer to install MPV or edit global `PATH`.

#### Scenario: Bundled DLL exists beside the executable
- **WHEN** the concrete backend is created on Windows and `libmpv-2.dll` exists
  beside the running executable
- **THEN** the backend passes that DLL path to `MediaKit.ensureInitialized`
  before creating the player

#### Scenario: Explicit DLL path is supplied by packaging smoke
- **WHEN** a smoke tool or composition root supplies an explicit libmpv DLL path
- **THEN** the backend uses that path instead of relying on ambient machine
  state

#### Scenario: Bundled DLL is unavailable
- **WHEN** no explicit or bundled DLL path is available
- **THEN** player operations continue to return normalized playback failures
  rather than exposing media_kit native initialization exceptions

