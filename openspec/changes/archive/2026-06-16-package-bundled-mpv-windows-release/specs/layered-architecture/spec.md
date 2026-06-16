## MODIFIED Requirements

### Requirement: Concrete implementation slices SHALL preserve UI ownership boundaries
Concrete runtime implementation changes SHALL keep UI implementation work
separate when ownership is assigned to an external UI track. Core implementation
changes MAY expose stable contracts and release packaging tools for UI/app-shell
consumption, but MUST NOT add app shells, routes, pages, widgets, file picker
UX, or video-surface widgets when the change scope excludes UI.

#### Scenario: Player core release packaging is implemented
- **WHEN** bundled MPV packaging support is added as a core implementation slice
- **THEN** `lib/src/ui/**` and `lib/main.dart` remain untouched while Playback
  and release tooling provide the integration surface for future UI work

