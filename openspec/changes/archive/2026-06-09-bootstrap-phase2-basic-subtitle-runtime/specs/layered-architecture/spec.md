## ADDED Requirements

### Requirement: Basic subtitle runtime SHALL preserve layer isolation
The basic subtitle runtime SHALL keep parser, scanner, offset, cue-resolution, and runtime composition dependencies within allowed Playback and Domain-facing contract boundaries and MUST NOT introduce dependencies from Playback or Domain into UI, concrete Provider implementations, Gateway implementations, Storage implementations, Streaming implementations, Network implementations, diagnostics UI, or native player bindings.

#### Scenario: Subtitle runtime imports are checked
- **WHEN** automation scans the basic subtitle runtime, subtitle parser implementations, scanner implementations, and Domain-facing subtitle state files
- **THEN** the scan finds no imports of Flutter widgets, MPV, VLC, libmpv, media-kit, platform channels, concrete provider implementations, gateway internals, storage internals, streaming engines, network clients, diagnostics UI, BT engines, Bangumi, Dandanplay, RSS runtime, online rule runtime, or advanced caption rendering internals

### Requirement: Advanced caption rendering SHALL remain downstream of basic subtitle runtime
Advanced caption rendering SHALL depend on basic subtitle cue/source contracts only through explicit extension boundaries, and the basic subtitle runtime MUST NOT import advanced caption rendering implementation details.

#### Scenario: Advanced caption work is absent
- **WHEN** the basic subtitle runtime is validated before advanced caption rendering implementation
- **THEN** parser, scanner, offset, active-cue, and subtitle state validation passes without advanced caption rendering code
