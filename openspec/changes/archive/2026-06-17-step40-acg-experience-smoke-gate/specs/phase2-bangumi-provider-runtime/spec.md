## ADDED Requirements

### Requirement: Bangumi provider runtime SHALL participate in the ACG smoke gate
The Bangumi provider runtime SHALL be consumable by a non-UI ACG experience
smoke gate through `AcgDataController` without requiring Flutter widgets,
native player bindings, storage migrations, or direct HTTP client access.

#### Scenario: ACG smoke gate resolves Bangumi metadata
- **WHEN** the ACG smoke gate is given a Bangumi subject id
- **THEN** it retrieves subject metadata through the existing provider runtime
  surface and reports typed provider failures without exposing Bangumi API
  transport details
