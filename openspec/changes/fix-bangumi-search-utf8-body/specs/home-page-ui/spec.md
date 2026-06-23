## MODIFIED Requirements

### Requirement: Home Page Search
The home page SHALL provide a search entry that opens a focused search surface
for Bangumi anime subjects, including subjects queried with Chinese text.

#### Scenario: Chinese search result opens detail
- **WHEN** the user searches a Chinese Bangumi keyword
- **THEN** the app sends the query through the home search provider
- **AND** matching suggestions are displayed in the search surface
- **AND** selecting a result closes search and opens the existing detail surface
