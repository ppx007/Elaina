## ADDED Requirements

### Requirement: Bangumi popular anime SHALL use recent heat sorting
Bangumi discovery for home recommendations SHALL request recent popular anime
using Bangumi heat sorting instead of historical rank sorting.

#### Scenario: Home recommendations request popular anime
- **WHEN** the concrete Bangumi provider loads popular anime for the home page
- **THEN** the request uses the anime subject type and heat sorting
- **AND** it requests seven subjects for the home hero/recommendation feed
- **AND** it does not use historical rank sorting as the recommendation order
