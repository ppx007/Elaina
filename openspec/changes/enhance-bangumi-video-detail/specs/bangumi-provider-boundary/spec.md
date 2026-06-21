## ADDED Requirements

### Requirement: Bangumi provider SHALL expose subject relation tables
Bangumi provider contracts SHALL expose subject persons, subject characters,
voice actors, and related subjects as provider-normalized data without exposing
Bangumi endpoint paths or JSON shapes to Domain or UI layers.

#### Scenario: Domain requests subject staff and cast
- **WHEN** Domain asks for related persons, related characters, or related
  subjects for a Bangumi subject id
- **THEN** the request is routed through `BangumiProvider` contracts and
  ProviderGateway request keys rather than direct UI or Domain HTTP access

### Requirement: Concrete Bangumi detail-table requests SHALL use ProviderGateway
Concrete Bangumi API requests MUST use ProviderGateway for subject persons,
characters, and relations registration, rate policy, proxy context, cache
policy, retry handling, and normalized failure behavior.

#### Scenario: Concrete provider loads subject characters
- **WHEN** the concrete Bangumi provider loads character/CV data for a subject
- **THEN** it requests `/v0/subjects/{subject_id}/characters` through
  ProviderGateway, forwards proxy context to the transport, and returns
  `AcgProviderResult` values
