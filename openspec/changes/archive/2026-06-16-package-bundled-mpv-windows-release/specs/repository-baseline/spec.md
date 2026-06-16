## ADDED Requirements

### Requirement: Windows release packaging SHALL produce unzip-and-run artifacts
Windows release packaging SHALL verify that the release directory or zip
contains an application executable and `libmpv-2.dll` in the executable
directory. The packaging flow MUST NOT require customer-side PATH mutation,
global MPV installation, or repository-committed third-party binaries.

#### Scenario: Release directory is packaged
- **WHEN** the packaging script receives a Windows release directory and a
  libmpv source directory or DLL path
- **THEN** it copies `libmpv-2.dll` beside the executable and writes a zip
  artifact containing both files

#### Scenario: Required release inputs are missing
- **WHEN** the release directory, app executable, or libmpv DLL source is
  missing
- **THEN** packaging fails with an actionable error instead of producing a
  partial artifact

