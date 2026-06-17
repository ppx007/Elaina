# phase2-bangumi-provider-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase2-bangumi-provider-runtime. Update Purpose after archive.
## Requirements
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

### Requirement: Bangumi runtime SHALL support concrete provider injection
The Bangumi provider runtime SHALL support injection of concrete metadata and
auth/progress providers while preserving deterministic fixture providers for
offline bootstrap validation.

#### Scenario: Concrete Bangumi provider is configured
- **WHEN** app composition creates a concrete Bangumi API client and injects it
  into the Bangumi runtime
- **THEN** runtime lifecycle, provider registration, gateway execution,
  request-key semantics, and normalized result mapping remain the same as the
  deterministic runtime path

### Requirement: Bangumi concrete runtime SHALL keep auth optional
The concrete Bangumi runtime path SHALL support session and progress operations
only when an access token provider is configured and SHALL return normalized
unauthenticated results when no token is available.

#### Scenario: Progress sync is requested without a token
- **WHEN** a concrete Bangumi auth provider has no active access token
- **THEN** progress sync returns an unauthenticated `AcgProviderFailure` without
  dispatching an authenticated API request and without blocking metadata lookup

### Requirement: Bangumi provider runtime SHALL participate in the ACG smoke gate
The Bangumi provider runtime SHALL be consumable by a non-UI ACG experience
smoke gate through `AcgDataController` without requiring Flutter widgets,
native player bindings, storage migrations, or direct HTTP client access.

#### Scenario: ACG smoke gate resolves Bangumi metadata
- **WHEN** the ACG smoke gate is given a Bangumi subject id
- **THEN** it retrieves subject metadata through the existing provider runtime
  surface and reports typed provider failures without exposing Bangumi API
  transport details

