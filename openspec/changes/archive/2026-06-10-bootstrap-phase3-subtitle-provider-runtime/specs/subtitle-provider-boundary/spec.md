## ADDED Requirements

### Requirement: SubtitleProvider SHALL be consumable by subtitle-provider runtime
The subtitle provider boundary SHALL be directly consumable by the Step 15 subtitle-provider runtime through existing `SubtitleProvider`, `SubtitleSearchQuery`, `SubtitleProviderCandidate`, `RetrievedSubtitleFile`, and `SubtitleProviderCachePolicy` contracts.

#### Scenario: Runtime invokes subtitle provider search
- **WHEN** the subtitle-provider runtime searches provider subtitles
- **THEN** it receives provider candidates or normalized provider failures through existing provider result contracts without concrete UI, storage implementation, RSS, seasonal, BT, online-rule, diagnostics, network client, or native-player bindings

### Requirement: SubtitleProvider runtime consumption SHALL preserve ProviderGateway policy boundaries
Subtitle provider runtime consumption SHALL preserve provider registration, rate policy, retry policy, gateway cache policy, and normalized failure behavior rather than implementing provider-specific network governance inside Domain runtime code.

#### Scenario: Provider runtime depends on gateway-bound provider contract
- **WHEN** a subtitle provider is configured for runtime use
- **THEN** provider-facing traffic remains represented by `GatewayBoundProvider`, `ProviderRegistration`, and `SubtitleProviderCachePolicy` contracts while durable cache state remains outside concrete runtime ownership

### Requirement: SubtitleProvider retrieval SHALL remain parser-compatible
Provider subtitle retrieval through the runtime SHALL preserve supported subtitle format, source metadata, retrieved content, encoding hints, and candidate identity needed for parser handoff.

#### Scenario: Runtime retrieves subtitle file
- **WHEN** a provider candidate is retrieved through runtime actions
- **THEN** the retrieved file can be converted into a `SubtitleParseRequest` compatible with basic subtitle parser contracts without advanced caption rendering, native player startup, UI state, or provider implementation coupling

### Requirement: SubtitleProvider runtime checks MUST reject later-phase dependencies
Validation for the Step 15 subtitle-provider runtime slice MUST reject RSS, seasonal, BT, online-rule, diagnostics, advanced caption rendering, concrete Flutter UI, storage implementation, network client, MPV/VLC, native-player, scraping, and captcha automation dependencies.

#### Scenario: Subtitle provider runtime boundary is checked
- **WHEN** automation scans subtitle-provider runtime and checker files
- **THEN** forbidden later-phase and concrete implementation dependencies are rejected while provider subtitle contracts remain allowed
