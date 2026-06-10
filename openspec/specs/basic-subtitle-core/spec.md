# basic-subtitle-core Specification

## Purpose
TBD - created by archiving change bootstrap-acg-data-experience. Update Purpose after archive.
## Requirements
### Requirement: Basic subtitle sources SHALL be represented independently of providers
The system SHALL represent embedded and external subtitle sources without requiring provider-backed subtitle discovery.

#### Scenario: External subtitle is selected
- **WHEN** a local external subtitle reference is attached to playback
- **THEN** the subtitle source is represented through Playback contracts without calling a subtitle provider

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

### Requirement: Subtitle offsets MUST follow player-clock timing
The system MUST apply subtitle offset behavior relative to player-clock timing rather than wall-clock timing.

#### Scenario: Subtitle offset is applied
- **WHEN** a subtitle cue is displayed with a configured offset
- **THEN** the cue timing is calculated from player-clock position plus the offset

### Requirement: Provider subtitle handoff SHALL preserve parser-compatible source metadata
The system SHALL preserve subtitle source id, format, language, URI, title, content, and encoding hint when converting retrieved provider subtitles into parser requests.

#### Scenario: Retrieved provider file becomes parser input
- **WHEN** Domain prepares a retrieved provider subtitle file for parsing
- **THEN** the parser request contains the external subtitle source metadata, subtitle content, and encoding hint required by parser contracts

### Requirement: Basic subtitle core SHALL remain independent of advanced subtitle rendering
The system SHALL keep dual subtitles, PGS rendering intent, and ASS enhancement intent in advanced caption rendering contracts while preserving basic subtitle source, parser, cue, scanner, provider handoff, and offset behavior.

#### Scenario: Dual subtitles are enabled
- **WHEN** advanced caption rendering prepares primary and secondary subtitle tracks
- **THEN** basic subtitle parsing and cue timing remain player-clock-based and unchanged

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

### Requirement: Basic subtitle core SHALL accept runtime provider handoff requests
Basic subtitle core SHALL accept `SubtitleParseRequest` values produced by subtitle-provider runtime retrieval handoff without requiring provider-specific, cache-specific, UI-specific, storage-specific, or native-player-specific parser models.

#### Scenario: Runtime provider file becomes parser input
- **WHEN** subtitle-provider runtime prepares a retrieved provider subtitle file
- **THEN** basic subtitle parser contracts can parse the resulting request using existing SRT, VTT, or ASS parser behavior while preserving source metadata and encoding hints

### Requirement: Basic subtitle core SHALL remain independent of provider runtime lifecycle
Basic subtitle parsing and runtime active-cue lookup SHALL remain independent of subtitle-provider runtime lifecycle, cache state, provider authentication, network availability, UI state, and native player bindings.

#### Scenario: Provider runtime is unavailable
- **WHEN** subtitle-provider runtime is disposed, unavailable, or returns a normalized provider failure
- **THEN** existing loaded local or retrieved subtitle parser behavior remains unchanged and player-clock-based subtitle timing still uses basic subtitle core contracts

### Requirement: Basic subtitle core MUST NOT absorb provider retrieval concerns
Basic subtitle core MUST NOT implement provider search, provider retrieval, cache TTL, ProviderGateway policy, OpenSubtitles clients, scraping, captcha automation, RSS, seasonal indexing, BT, online-rule, diagnostics, advanced caption rendering, MPV/VLC, or native-player behavior.

#### Scenario: Basic subtitle boundary is checked
- **WHEN** validation scans basic subtitle parser and runtime files after Step 15
- **THEN** provider retrieval remains in Domain/provider runtime contracts while basic subtitle parsing stays parser-focused and player-clock-based

