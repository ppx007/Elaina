## ADDED Requirements

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
