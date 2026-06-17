## ADDED Requirements

### Requirement: Dandanplay provider runtime SHALL participate in the ACG smoke gate
The Dandanplay provider runtime SHALL be consumable by a non-UI ACG experience
smoke gate through `AcgDataController` and `PlaybackMetadataBridge` without
requiring Flutter widgets, native renderer handles, storage migrations, or
direct HTTP client access.

#### Scenario: ACG smoke gate resolves Dandanplay enrichment
- **WHEN** the ACG smoke gate is given a local media filename
- **THEN** it performs match lookup, loads comments for the selected episode,
  projects danmaku through the playback metadata bridge, and reports typed
  provider failures without exposing Dandanplay API transport details
