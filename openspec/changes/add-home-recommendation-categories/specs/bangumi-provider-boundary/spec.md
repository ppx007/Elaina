## MODIFIED Requirements

### Requirement: Bangumi discovery SHALL use API recent-popular search for more recommendations
Bangumi discovery used by the home "热门番组" waterfall SHALL retrieve recent
popular anime from Bangumi v0 subject search using heat sorting, a 180-day
air-date window, and an optional Bangumi `meta_tags` category filter.

#### Scenario: Default热门番组 recommendations are requested
- **WHEN** the home page requests lower recommendation waterfall entries for
  the default category
- **THEN** the provider requests `/v0/search/subjects`
- **AND** the POST body uses `sort=heat`
- **AND** the POST body filters anime subjects whose `air_date` is within the
  last 180 days
- **AND** the POST body does not include `meta_tags`
- **AND** the request is routed through ProviderGateway with a deterministic
  category-aware recent-popular cache key, network policy URI, and proxy context

#### Scenario: Tagged recommendations are requested
- **WHEN** the home page requests a lower recommendation category such as
  "日常" or "百合"
- **THEN** the provider keeps the recent-popular API search semantics
- **AND** the POST body adds `filter.meta_tags` with the selected Bangumi tag
- **AND** the tagged request uses a cache key segment distinct from the default
  category

#### Scenario: Recent-popular API fails
- **WHEN** the Bangumi v0 recent-popular response fails or is malformed
- **THEN** the provider returns a normalized provider failure
- **AND** it does not fall back to the official trends browser page or another
  recommendation category
