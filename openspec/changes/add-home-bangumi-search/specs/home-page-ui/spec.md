## ADDED Requirements

### Requirement: Home Page Search
The home page SHALL provide a search entry that opens a focused search surface
for Bangumi anime subjects.

#### Scenario: Search entry opens typeahead
- **WHEN** the user activates the home search entry
- **THEN** the app opens a full-screen search surface with a focused input

#### Scenario: Search result opens detail
- **WHEN** the user selects a Bangumi search result
- **THEN** the search surface closes and the existing video detail surface opens
  for the selected subject

#### Scenario: Search handles loading and failure
- **WHEN** the search provider is loading, empty, or failed
- **THEN** the search surface shows a clear corresponding state without
  blocking the rest of the app
