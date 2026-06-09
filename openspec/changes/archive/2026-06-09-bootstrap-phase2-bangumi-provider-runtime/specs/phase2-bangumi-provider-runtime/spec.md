## ADDED Requirements

### Requirement: Bangumi runtime SHALL compose gateway-governed metadata providers
The Phase 2 Bangumi provider runtime SHALL compose subject lookup, subject search, episode lookup, provider registration, provider request keys, gateway execution, and normalized result mapping without concrete HTTP transport, UI OAuth screens, token persistence, playback, subtitle runtime, Dandanplay, RSS, streaming, or native player dependencies.

#### Scenario: Runtime is constructed offline
- **WHEN** the Bangumi runtime is constructed with deterministic metadata fixtures and a ProviderGateway
- **THEN** it registers the Bangumi provider and exposes subject, search, and episode lookup through Bangumi provider contracts without concrete network dispatch or UI dependencies

### Requirement: Bangumi runtime SHALL expose optional auth session state
The Bangumi runtime SHALL expose current auth session state as optional enrichment and SHALL return normalized unauthenticated results when no session is available.

#### Scenario: User is unauthenticated
- **WHEN** Domain asks for current Bangumi session without a configured auth session
- **THEN** the runtime returns an unauthenticated provider result without blocking playback, subtitle runtime, Dandanplay, RSS, BT, or online-rule flows

### Requirement: Bangumi runtime SHALL normalize progress sync outcomes
The Bangumi runtime SHALL route progress-sync requests through the auth/progress provider contract and SHALL return success, unauthenticated, retryable, throttled, not-found, or terminal outcomes as `AcgProviderResult` values.

#### Scenario: Progress sync is unavailable
- **WHEN** progress sync is requested without an active Bangumi auth session
- **THEN** the runtime returns a normalized unauthenticated result and does not throw a UI, network, storage, playback, or native exception

### Requirement: Bangumi runtime SHALL preserve deterministic lifecycle behavior
The Bangumi runtime SHALL expose lifecycle-safe behavior for available, unavailable, and disposed runtime states.

#### Scenario: Runtime is disposed
- **WHEN** subject lookup, episode lookup, session lookup, or progress sync is requested after disposal
- **THEN** the runtime returns a normalized unavailable or terminal provider result without dispatching gateway loaders
