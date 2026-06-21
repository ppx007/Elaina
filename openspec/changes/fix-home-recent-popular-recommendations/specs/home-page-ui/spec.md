## ADDED Requirements

### Requirement: Home recommendations SHALL present recent popularity
The home page recommendation section SHALL present Bangumi recommendations as
recent popular content, not as a historical ranking chart.

#### Scenario: Recent popular recommendations are displayed
- **WHEN** a Bangumi recommendation item includes score, collection count, and
  historical rank metadata
- **THEN** the home page labels the section as recent popular content
- **AND** the metadata sentence may show score and collection count
- **AND** it does not render the historical Bangumi rank as recommendation copy

### Requirement: Home recommendation entries SHALL open global detail
Bangumi recommendation entries on the home page SHALL open the shared global
video detail surface when they represent a real Bangumi subject.

#### Scenario: User opens a home recommendation
- **WHEN** the user selects a hero or hot recommendation entry with a subject id
- **THEN** the app opens the same video detail surface used by tracking and
  local media entries
- **AND** placeholder recommendation entries without a subject id remain
  non-navigating

### Requirement: Home hero carousel SHALL show seven hot recommendations
The top home carousel SHALL be populated from the recent popular recommendation
feed and SHALL show at most seven real Bangumi subjects.

#### Scenario: Hot recommendations feed has more than seven subjects
- **WHEN** the home page receives more than seven recent popular recommendation
  items
- **THEN** the top hero carousel renders only the first seven items
- **AND** those entries retain their subject ids for global detail navigation

### Requirement: Home recent watching SHALL use tracking data
The home page middle section SHALL be titled "最近观看" and SHALL use Bangumi
tracking data instead of the popular recommendation feed.

#### Scenario: User is not authenticated
- **WHEN** the tracking provider is unavailable or reports an unauthenticated
  state
- **THEN** the recent watching section displays "请登录"
- **AND** it does not render placeholder watching entries

#### Scenario: User has watched anime
- **WHEN** the authenticated tracking snapshot contains anime with watched
  progress
- **THEN** the recent watching section renders those anime in the scrolling
  carousel
- **AND** planned-only anime without watched progress are excluded

### Requirement: More recommendations SHALL use a waterfall layout
The home page "更多推荐" area SHALL lay out recommendation cards as a waterfall
instead of a uniform grid.

#### Scenario: Recommendations are displayed below recent watching
- **WHEN** the home page renders recommendation cards below "更多推荐"
- **THEN** cards are distributed into responsive waterfall columns
- **AND** real recommendation cards keep global detail navigation
