# phase3-subtitle-provider-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase3-subtitle-provider-runtime. Update Purpose after archive.
## Requirements
### Requirement: Subtitle provider runtime SHALL compose existing subtitle contracts
The system SHALL provide a deterministic subtitle-provider runtime or bootstrap that wires `SubtitleProvider`, `SubtitleDiscoveryContract`, subtitle cache contracts, retrieved subtitle files, and parser handoff behind a Domain-facing runtime surface.

#### Scenario: Runtime is bootstrapped
- **WHEN** the subtitle-provider runtime is created with deterministic provider, discovery, cache, and parser-handoff dependencies
- **THEN** callers can use one runtime surface for provider search, cache-aware discovery, retrieval, parser handoff, lifecycle snapshots, and normalized failures without importing storage implementations, concrete provider clients, UI widgets, network clients, RSS, seasonal, BT, diagnostics, MPV, VLC, or native-player bindings

### Requirement: Subtitle provider runtime SHALL expose deterministic snapshots and failures
The subtitle-provider runtime SHALL expose lifecycle-safe snapshots, result values, and typed failures for idle, searching, retrieving, ready, failed, and disposed states.

#### Scenario: Runtime is disposed
- **WHEN** a caller invokes a subtitle-provider action after disposal
- **THEN** the runtime returns or publishes a deterministic disposed/unavailable outcome instead of throwing provider, storage, UI, network, platform, playback, or native-player exceptions

### Requirement: Subtitle provider runtime SHALL support search and cache-aware discovery
The subtitle-provider runtime SHALL execute provider-backed subtitle discovery through existing `SubtitleDiscoveryContract` behavior, expose local/provider candidates, report normalized provider failures, and preserve cache-hit indicators.

#### Scenario: Provider subtitles are searched
- **WHEN** a subtitle provider search is requested for local media and a provider query
- **THEN** local candidates, provider candidates, cache-hit state, and provider failures are returned through Domain subtitle contracts without requiring concrete provider clients, database migration, RSS, seasonal indexing, BT, online-rule, network, UI, or native-player behavior

### Requirement: Subtitle provider runtime SHALL retrieve and prepare parser handoff
The subtitle-provider runtime SHALL retrieve selected provider candidates through existing provider/cache contracts and produce `SubtitleParseRequest` values compatible with basic subtitle parser contracts.

#### Scenario: Provider subtitle is selected
- **WHEN** a provider subtitle candidate is selected and retrieval succeeds or uses cached content
- **THEN** the runtime returns the retrieved file and parser request while preserving format, source metadata, content, encoding hints, and cache-hit state without parsing subtitles directly or invoking native-player code

### Requirement: Subtitle provider runtime MUST preserve Step 15 boundaries
The subtitle-provider runtime MUST NOT implement concrete OpenSubtitles clients, scraping, captcha automation, Flutter UI, storage migrations, RSS engine, seasonal indexer, BT streaming, online-rule parsing, advanced caption rendering, diagnostics, MPV/VLC, or native-player bindings.

#### Scenario: Runtime boundaries are checked
- **WHEN** validation scans Step 15 runtime, tests, and tool files
- **THEN** forbidden later-phase dependencies and concrete implementation shortcuts are rejected while provider subtitle, subtitle discovery, cache, and basic subtitle parser handoff contracts remain allowed

