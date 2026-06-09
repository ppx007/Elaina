## ADDED Requirements

### Requirement: Dandanplay runtime SHALL compose gateway-governed provider operations
The Phase 2 Dandanplay provider runtime SHALL compose local media matching, subject search, comment retrieval, comment posting, provider registration, deterministic request keys, gateway execution, and normalized result mapping without concrete HTTP transport, UI login screens, token persistence, playback runtime, subtitle runtime, Bangumi runtime dependency, RSS, streaming, online-rule, or native player dependencies.

#### Scenario: Runtime is constructed offline
- **WHEN** the Dandanplay runtime is constructed with deterministic match and comment fixtures plus a ProviderGateway
- **THEN** it registers the Dandanplay provider and exposes match, search, comments, and comment-posting operations through Dandanplay provider contracts without concrete network dispatch or UI dependencies

### Requirement: Dandanplay runtime SHALL expose optional match and comment enrichment
The Dandanplay runtime SHALL expose match, search, comments, and posting as optional enrichment and SHALL return normalized provider failures when fixtures or gateway operations are unavailable.

#### Scenario: Dandanplay match is unavailable
- **WHEN** Domain asks for a Dandanplay local media match and the runtime has no matching deterministic candidate
- **THEN** the runtime returns a normalized provider result without blocking playback, subtitle runtime, Bangumi metadata, RSS, BT, or online-rule flows

### Requirement: Dandanplay runtime SHALL normalize comment outcomes
The Dandanplay runtime SHALL route comment retrieval and comment posting through provider-governed execution and SHALL return success, retryable, throttled, cached-miss, terminal, or unavailable outcomes as `AcgProviderResult` values.

#### Scenario: Comment posting fails through the gateway
- **WHEN** ProviderGateway reports a throttled or retryable Dandanplay comment-post request
- **THEN** the runtime returns an `AcgProviderFailure` with normalized provider semantics instead of leaking gateway exceptions

### Requirement: Dandanplay runtime SHALL preserve deterministic lifecycle behavior
The Dandanplay runtime SHALL expose lifecycle-safe behavior for available, unavailable, and disposed runtime states.

#### Scenario: Runtime is disposed
- **WHEN** match, search, comment retrieval, comment posting, or direct gateway execution is requested after disposal
- **THEN** the runtime returns a normalized unavailable or terminal provider result without registering the provider or dispatching gateway loaders
