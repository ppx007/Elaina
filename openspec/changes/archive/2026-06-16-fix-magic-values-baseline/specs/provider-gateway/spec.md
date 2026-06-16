## ADDED Requirements

### Requirement: Provider fallback sentinels SHALL use named gateway policies
Unavailable provider sentinels SHALL express gateway registration policy through
named constants or helpers so sentinel rate and retry behavior is not encoded as
duplicated inline numeric values.

#### Scenario: Optional provider is unavailable
- **WHEN** a runtime composes an unavailable provider placeholder
- **THEN** the placeholder registers with named sentinel rate and retry policy
  values while still returning normalized unavailable failures for provider
  operations
