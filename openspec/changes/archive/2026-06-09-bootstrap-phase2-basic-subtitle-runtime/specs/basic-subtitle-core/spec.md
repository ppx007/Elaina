## ADDED Requirements

### Requirement: Basic subtitle core SHALL provide deterministic SRT parsing
The basic subtitle core SHALL include a deterministic SRT parser that normalizes cue indexes, start/end timing, multiline text payloads, and parser warnings behind the existing `SubtitleParser` contract.

#### Scenario: SRT content is parsed
- **WHEN** valid SRT content with one or more timed cues is parsed
- **THEN** the parser returns a subtitle track with normalized cue timing and text without requiring native player, provider, storage, streaming, network, or UI dependencies

### Requirement: Basic subtitle core SHALL provide deterministic WebVTT parsing
The basic subtitle core SHALL include a deterministic WebVTT parser that normalizes cue identifiers, timestamp lines, cue settings, multiline text payloads, and parser warnings behind the existing `SubtitleParser` contract.

#### Scenario: WebVTT content is parsed
- **WHEN** valid WebVTT content is parsed
- **THEN** the parser returns normalized cues and preserves supported cue settings as metadata without requiring native player, provider, storage, streaming, network, or UI dependencies

### Requirement: Basic subtitle core SHALL provide basic ASS dialogue parsing
The basic subtitle core SHALL include a deterministic basic ASS parser that extracts dialogue timing and text into normalized cues while leaving advanced style/layout rendering to advanced caption rendering contracts.

#### Scenario: ASS dialogue content is parsed
- **WHEN** ASS content contains dialogue rows with start time, end time, and text fields
- **THEN** the parser returns normalized text cues and does not attempt advanced ASS rendering, PGS rendering, dual subtitles, or GPU overlay behavior

### Requirement: Local subtitle scanning SHALL be deterministic and media-adjacent
The basic subtitle core SHALL provide local subtitle scanning that discovers SRT, VTT, and ASS candidates associated with an already-selected local media value through deterministic media-adjacent inputs.

#### Scenario: Media-adjacent subtitles are discovered
- **WHEN** local media has adjacent subtitle candidates matching the supported subtitle formats
- **THEN** the scanner returns external subtitle candidates with normalized sources and confidence values without provider lookup, database access, broad filesystem traversal, network requests, or native player startup

### Requirement: Subtitle offset lookup SHALL be runtime-backed
The basic subtitle core SHALL apply configured subtitle offset through runtime active-cue lookup using `PlayerClockSnapshot` position rather than wall-clock time.

#### Scenario: Cue is shifted by offset
- **WHEN** a subtitle offset is configured and active cues are resolved for a player-clock snapshot
- **THEN** cue activation is evaluated against player-clock position plus the configured offset
