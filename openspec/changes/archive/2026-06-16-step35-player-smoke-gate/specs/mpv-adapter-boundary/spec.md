## ADDED Requirements

### Requirement: Concrete MPV smoke gate SHALL verify non-UI playback when native dependencies are available
The concrete MPV smoke gate SHALL run a non-UI playback command sequence
against a local media file through the public player runtime composition
contract when a `libmpv-2.dll` path and sample media are available.

#### Scenario: Native smoke dependencies are supplied
- **WHEN** the smoke gate receives an explicit libmpv DLL path or directory and
  a local sample media file, or can generate a temporary sample file
- **THEN** it runs load, play, pause, seek, stop, and dispose through the
  media_kit/libmpv binding smoke tool without requiring Flutter UI code

#### Scenario: Native smoke dependencies are absent
- **WHEN** libmpv or sample media dependencies are absent and strict native
  smoke is not requested
- **THEN** the smoke gate records the skipped native step explicitly rather
  than treating deterministic unit tests as proof of native playback
