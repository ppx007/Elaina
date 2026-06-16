# phase2-dandanplay-provider-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase2-dandanplay-provider-runtime. Update Purpose after archive.
## Requirements
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

### Requirement: Dandanplay runtime SHALL support concrete provider injection
The Dandanplay provider runtime SHALL support injection of concrete match and
comment providers while preserving deterministic fixture providers for offline
bootstrap validation.

#### Scenario: Concrete Dandanplay provider is configured
- **WHEN** app composition creates a concrete Dandanplay API client and injects
  it into the Dandanplay runtime
- **THEN** runtime lifecycle, provider registration, gateway execution,
  request-key semantics, and normalized result mapping remain the same as the
  deterministic runtime path

### Requirement: Dandanplay concrete runtime SHALL keep posting optional
The concrete Dandanplay runtime path SHALL support comment posting only when
the required bearer token or app credentials are configured and SHALL return
normalized unauthenticated results when posting credentials are absent.

#### Scenario: Comment posting is requested without credentials
- **WHEN** a concrete Dandanplay comment provider has no posting credentials
- **THEN** comment posting returns an unauthenticated `AcgProviderFailure`
  without dispatching a privileged API request and without blocking match,
  search, or comment retrieval

