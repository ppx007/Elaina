## MODIFIED Requirements

### Requirement: Home hero carousel SHALL show seven hot recommendations
The top home carousel SHALL be populated from Bangumi's official anime trends
feed and SHALL show at most seven real Bangumi subjects.

#### Scenario: Official trends feed has more than seven subjects
- **WHEN** the home page receives more than seven official trends items
- **THEN** the top hero carousel renders only the first seven items
- **AND** those entries retain their subject ids for global detail navigation

### Requirement: More recommendations SHALL use a waterfall layout
The home page "更多推荐" area SHALL lay out official Bangumi trends entries as a
waterfall instead of a uniform grid.

#### Scenario: Recommendations are displayed below recent watching
- **WHEN** the home page renders recommendation cards below "更多推荐"
- **THEN** cards are distributed into responsive waterfall columns
- **AND** entries already shown in the hero carousel are not duplicated in the
  waterfall
- **AND** real recommendation cards keep global detail navigation
