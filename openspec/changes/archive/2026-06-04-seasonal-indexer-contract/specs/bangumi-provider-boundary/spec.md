## MODIFIED Requirements

### Requirement: Bangumi provider SHALL expose subject and episode lookup contracts
The system SHALL define Bangumi provider contracts for subject lookup, subject search, and episode lookup as optional metadata enrichment, including queue-driven subject search for seasonal catalog entries.

#### Scenario: Subject metadata is requested
- **WHEN** Domain requests Bangumi subject metadata or seasonal match candidates
- **THEN** the request is routed through a provider contract rather than direct UI access to Bangumi APIs

## ADDED Requirements

### Requirement: Bangumi match queue SHALL use provider-governed search
The system SHALL search Bangumi candidates for seasonal catalog entries through `BangumiProvider` and `ProviderGateway` instead of direct Domain or UI access to Bangumi APIs.

#### Scenario: Seasonal entry needs match candidates
- **WHEN** a Bangumi match queue worker processes a seasonal catalog entry
- **THEN** it searches subjects through Bangumi provider contracts and stores normalized candidates for later automatic or user-confirmed binding
