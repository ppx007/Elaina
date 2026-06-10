## ADDED Requirements

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
