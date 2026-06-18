## ADDED Requirements

### Requirement: VLC fallback runtime SHALL accept concrete VLC fallback candidates
The fallback adapter runtime SHALL allow a Playback-owned concrete VLC fallback
candidate to be registered and selected through the existing deterministic
fallback strategy without importing concrete VLC packages or invoking backend
commands from the runtime slice.

#### Scenario: Runtime selects concrete VLC fallback candidate
- **WHEN** the runtime registers a VLC fallback candidate and receives a
  fallback-compatible primary load failure for a supported local file source
- **THEN** selection succeeds through the existing typed projection while the
  runtime remains free of VLC backend imports and direct player command
  invocation
