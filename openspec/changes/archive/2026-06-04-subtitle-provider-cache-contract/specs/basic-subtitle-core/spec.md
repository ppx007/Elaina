## MODIFIED Requirements

### Requirement: Subtitle parsers SHALL cover SRT, VTT, and ASS cues
The system SHALL define parser contracts for SRT, VTT, and ASS subtitle cues, and parser requests SHALL preserve provider retrieval encoding hints when available.

#### Scenario: Subtitle file is parsed
- **WHEN** an SRT, VTT, or ASS subtitle source is parsed
- **THEN** the parser returns normalized cues with timing data and text payloads while receiving any available encoding hint from the retrieval handoff

### Requirement: Local external subtitle scanning SHALL discover media-adjacent subtitle candidates
The system SHALL define local external subtitle scanning contracts for discovering subtitle files associated with a media item without using provider-backed subtitle discovery, and Domain subtitle discovery SHALL be able to report those local results alongside provider candidates.

#### Scenario: Media-adjacent subtitle candidates are scanned
- **WHEN** playback is prepared for a local media item
- **THEN** the system can discover local SRT, VTT, or ASS subtitle candidates through Playback contracts without calling a subtitle provider

## ADDED Requirements

### Requirement: Provider subtitle handoff SHALL preserve parser-compatible source metadata
The system SHALL preserve subtitle source id, format, language, URI, title, content, and encoding hint when converting retrieved provider subtitles into parser requests.

#### Scenario: Retrieved provider file becomes parser input
- **WHEN** Domain prepares a retrieved provider subtitle file for parsing
- **THEN** the parser request contains the external subtitle source metadata, subtitle content, and encoding hint required by parser contracts
