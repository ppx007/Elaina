## ADDED Requirements

### Requirement: Basic subtitle sources SHALL be represented independently of providers
The system SHALL represent embedded and external subtitle sources without requiring provider-backed subtitle discovery.

#### Scenario: External subtitle is selected
- **WHEN** a local external subtitle reference is attached to playback
- **THEN** the subtitle source is represented through Playback contracts without calling a subtitle provider

### Requirement: Subtitle parsers SHALL cover SRT, VTT, and ASS cues
The system SHALL define parser contracts for SRT, VTT, and ASS subtitle cues.

#### Scenario: Subtitle file is parsed
- **WHEN** an SRT, VTT, or ASS subtitle source is parsed
- **THEN** the parser returns normalized cues with timing data and text payloads

### Requirement: Local external subtitle scanning SHALL discover media-adjacent subtitle candidates
The system SHALL define local external subtitle scanning contracts for discovering subtitle files associated with a media item without using provider-backed subtitle discovery.

#### Scenario: Media-adjacent subtitle candidates are scanned
- **WHEN** playback is prepared for a local media item
- **THEN** the system can discover local SRT, VTT, or ASS subtitle candidates through Playback contracts without calling a subtitle provider

### Requirement: Subtitle offsets MUST follow player-clock timing
The system MUST apply subtitle offset behavior relative to player-clock timing rather than wall-clock timing.

#### Scenario: Subtitle offset is applied
- **WHEN** a subtitle cue is displayed with a configured offset
- **THEN** the cue timing is calculated from player-clock position plus the offset
