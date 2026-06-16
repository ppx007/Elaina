## ADDED Requirements

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
