## ADDED Requirements

### Requirement: Bangumi discovery SHALL use official anime trends for the home hero
Bangumi discovery used by the home hero carousel SHALL retrieve official anime
trends from the Bangumi browser source rather than approximating trends with
subject search air-date filters.

#### Scenario: Home trends are requested
- **WHEN** the home page requests Bangumi hero recommendation entries
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

### Requirement: Bangumi discovery SHALL use API recent-popular search for more recommendations
Bangumi discovery used by the home "更多推荐" waterfall SHALL retrieve recent
popular anime from Bangumi v0 subject search using heat sorting and a 90-day
air-date window.

#### Scenario: More recommendations are requested
- **WHEN** the home page requests lower recommendation waterfall entries
- **THEN** the provider requests `/v0/search/subjects`
- **AND** the POST body uses `sort=heat`
- **AND** the POST body filters anime subjects whose `air_date` is within the
  last 90 days
- **AND** the request is routed through ProviderGateway with a deterministic
  recent-popular cache key, network policy URI, and proxy context

#### Scenario: Recent-popular API fails
- **WHEN** the Bangumi v0 recent-popular response fails or is malformed
- **THEN** the provider returns a normalized provider failure
- **AND** it does not fall back to the official trends browser page
