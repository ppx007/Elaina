## ADDED Requirements

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
