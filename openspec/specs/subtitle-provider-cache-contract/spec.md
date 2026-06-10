# subtitle-provider-cache-contract Specification

## Purpose
TBD - created by archiving change subtitle-provider-cache-contract. Update Purpose after archive.
## Requirements
### Requirement: Subtitle cache SHALL persist provider search results
The system SHALL define a Storage-layer subtitle cache contract that stores provider search results with provider id, normalized query key, cached timestamp, and expiration timestamp.

#### Scenario: Cached search results are reused
- **WHEN** a subtitle search is requested and a non-expired cache record exists for the provider and query
- **THEN** the cached provider candidates can be returned without requiring a new provider search request

### Requirement: Subtitle cache SHALL persist retrieved subtitle content
The system SHALL define a Storage-layer subtitle content cache contract that stores retrieved subtitle text, encoding hints, provider candidate identity, cached timestamp, and expiration timestamp.

#### Scenario: Retrieved subtitle content is cached
- **WHEN** a provider subtitle candidate is retrieved successfully
- **THEN** the retrieved content can be stored and later loaded through the subtitle cache contract until its file TTL expires

### Requirement: Domain subtitle discovery SHALL compose local and provider sources
The system SHALL define a Domain subtitle discovery contract that can combine local subtitle scanner results with provider-backed subtitle search results without requiring UI or concrete provider access.

#### Scenario: Subtitle discovery is requested for local media
- **WHEN** Domain requests subtitles for a local media reference and provider query
- **THEN** the discovery contract can return local candidates and provider candidates through Domain-facing data without direct UI/provider implementation coupling

### Requirement: Retrieved provider subtitles SHALL hand off to parser contracts
The system SHALL define a retrieval handoff contract that converts retrieved provider subtitle files into parser requests while preserving source metadata and encoding hints.

#### Scenario: Provider subtitle file is prepared for parsing
- **WHEN** a retrieved subtitle file has content, format, source metadata, and encoding hint
- **THEN** the handoff produces a parser request compatible with basic subtitle parsing contracts

### Requirement: Subtitle cache contracts SHALL support runtime provider search reuse
Subtitle cache contracts SHALL support deterministic runtime reuse of provider search results through provider id, normalized query key, cached timestamp, and expiration timestamp without requiring concrete database or storage implementation details.

#### Scenario: Runtime reuses cached subtitle search
- **WHEN** subtitle-provider runtime search receives a request with a non-expired cache record
- **THEN** cached provider candidates can be returned with cache-hit state without invoking provider search or requiring SQLite migrations, blob cache behavior, UI widgets, network clients, RSS, seasonal, BT, or native-player bindings

### Requirement: Subtitle cache contracts SHALL support runtime content reuse
Subtitle cache contracts SHALL support deterministic runtime reuse of retrieved subtitle content through provider id, candidate reference, cached subtitle content, encoding hints, cached URI, and expiration timestamp.

#### Scenario: Runtime reuses cached subtitle content
- **WHEN** subtitle-provider runtime prepares a provider subtitle candidate with non-expired cached content
- **THEN** the cached content can produce a parser handoff result without invoking provider retrieval or requiring concrete storage implementation, provider implementation, UI, network, diagnostics, or native-player behavior

### Requirement: Subtitle cache contracts SHALL support deterministic retrieval storage
Subtitle cache contracts SHALL support storing successful provider search and retrieval outcomes according to provider cache policy TTLs so later runtime calls can reuse them.

#### Scenario: Runtime stores provider retrieval result
- **WHEN** provider subtitle retrieval succeeds through runtime actions
- **THEN** retrieved content, encoding hints, cached URI, cached timestamp, and expiration timestamp are stored through subtitle cache contracts while concrete persistence remains outside the runtime slice

### Requirement: Subtitle cache runtime usage MUST remain storage-implementation-neutral
Subtitle-provider runtime cache usage MUST NOT require SQLite schema migrations, concrete cache databases, file-system cache writes, blob cache internals, provider SDKs, network clients, or UI state.

#### Scenario: Cache boundary is checked
- **WHEN** validation scans subtitle-provider runtime cache usage
- **THEN** only Storage-layer cache contracts and Domain/provider subtitle values are required for cache-aware search and retrieval

