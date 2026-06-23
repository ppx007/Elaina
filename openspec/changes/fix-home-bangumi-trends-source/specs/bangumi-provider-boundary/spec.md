## ADDED Requirements

### Requirement: Bangumi discovery SHALL use official anime trends for home recommendations
Bangumi discovery used by home recommendations SHALL retrieve official anime
trends from the Bangumi browser source rather than approximating trends with
subject search air-date filters.

#### Scenario: Home trends are requested
- **WHEN** the home page requests Bangumi recommendation entries
- **THEN** the provider requests `/anime/browser/?sort=trends`
- **AND** the request is routed through ProviderGateway with a deterministic
  trends cache key, network policy URI, and proxy context
- **AND** the provider returns normalized subject models instead of raw HTML

#### Scenario: Trends page cannot be parsed
- **WHEN** the Bangumi trends browser response does not contain parseable subject
  entries
- **THEN** the provider returns a normalized terminal provider failure
- **AND** it does not fall back to historical rank, v0 search heat, or stale
  local placeholder data
