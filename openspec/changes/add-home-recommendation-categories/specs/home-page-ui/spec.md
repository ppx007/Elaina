## MODIFIED Requirements

### Requirement: More recommendations SHALL use a waterfall layout
The home page lower recommendation area SHALL be titled "热门番组" and SHALL lay
out Bangumi API recent-popular entries as a waterfall instead of a uniform grid.

#### Scenario: Recommendations are displayed below recent watching
- **WHEN** the home page renders recommendation cards below "热门番组"
- **THEN** cards are distributed into responsive waterfall columns
- **AND** entries already shown in the hero carousel are not duplicated in the
  waterfall
- **AND** real recommendation cards keep global detail navigation

### Requirement: Home lower recommendations SHALL support common tag categories
The home page lower recommendation area SHALL expose a fixed category picker for
common anime tags while keeping "热门番组" as the default category.

#### Scenario: The user changes the recommendation category
- **WHEN** the user selects a non-default recommendation category
- **THEN** the lower waterfall clears its current pages and requests the first
  page for the selected category
- **AND** the hero carousel and recent watching area are not reloaded by that
  category switch
