## ADDED Requirements

### Requirement: Playback page foundation SHALL consume subtitle runtime descriptors indirectly
The playback page foundation SHALL consume subtitle availability, selected subtitle track identity, and active subtitle cue descriptors through Domain/UI-safe playback surfaces rather than importing subtitle parser implementations, subtitle runtime internals, native player bindings, provider systems, storage, streaming, network, diagnostics, or Flutter rendering internals.

#### Scenario: Subtitle cues are visible to playback page foundation
- **WHEN** a selected subtitle track has active cues resolved by the basic subtitle runtime
- **THEN** playback page foundation can consume descriptor data for those cues without owning parser, scanner, offset, native player, provider, storage, streaming, network, diagnostics, or advanced caption rendering behavior

### Requirement: Playback page foundation MUST NOT render advanced subtitle features in Step 9
The playback page foundation MUST NOT introduce dual subtitles, PGS rendering, ASS enhancement rendering, complex subtitle styling UI, or advanced caption layout behavior as part of the basic subtitle runtime slice.

#### Scenario: ASS subtitle contains style metadata
- **WHEN** a basic ASS subtitle track is available
- **THEN** playback page foundation receives normalized basic cue descriptors and leaves advanced style/layout rendering to later advanced caption rendering work
