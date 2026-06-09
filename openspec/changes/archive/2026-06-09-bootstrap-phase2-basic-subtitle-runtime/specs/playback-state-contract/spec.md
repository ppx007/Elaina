## ADDED Requirements

### Requirement: Playback state SHALL expose subtitle snapshot data without concrete runtime dependencies
Playback state contracts SHALL expose subtitle-related snapshot data such as available subtitle tracks, selected subtitle track identity, active cue descriptors, offset, warnings, or failure state using framework-neutral value types.

#### Scenario: Subtitle state is observed
- **WHEN** a playback consumer observes state after subtitles are loaded and a cue is active
- **THEN** the snapshot exposes subtitle data without Flutter widgets, BuildContext, parser implementation types, native player handles, provider clients, storage records, streaming objects, network responses, or diagnostics UI types

### Requirement: Playback state subtitle snapshots SHALL be immutable
Playback state subtitle snapshot values SHALL be immutable or defensively copied so callers cannot mutate runtime-owned track or cue state.

#### Scenario: Snapshot collection is reused
- **WHEN** a caller retains a subtitle state snapshot and the runtime later changes selected subtitle track or active cues
- **THEN** the retained snapshot remains a stable representation of the earlier state
