## ADDED Requirements

### Requirement: Player core smoke gate SHALL validate packaged release staging
The player core smoke gate SHALL validate that a Windows release directory can
stage `libmpv-2.dll` beside an application executable and produce a zip
containing both files, without requiring UI implementation in the core change.

#### Scenario: Release staging smoke runs
- **WHEN** the smoke gate has access to a libmpv DLL path or directory
- **THEN** it creates a temporary release directory, invokes the Windows
  packaging script, and verifies the generated zip contains a root executable
  and root `libmpv-2.dll`

#### Scenario: External UI runner is added later
- **WHEN** the external UI track adds the real Windows runner and executable
- **THEN** the same packaging script and smoke checklist apply to the real
  release directory without requiring customers to install MPV or edit global
  `PATH`
