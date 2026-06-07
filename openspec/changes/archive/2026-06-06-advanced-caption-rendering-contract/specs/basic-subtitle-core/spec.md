## ADDED Requirements

### Requirement: Basic subtitle core SHALL remain independent of advanced subtitle rendering
The system SHALL keep dual subtitles, PGS rendering intent, and ASS enhancement intent in advanced caption rendering contracts while preserving basic subtitle source, parser, cue, scanner, provider handoff, and offset behavior.

#### Scenario: Dual subtitles are enabled
- **WHEN** advanced caption rendering prepares primary and secondary subtitle tracks
- **THEN** basic subtitle parsing and cue timing remain player-clock-based and unchanged
