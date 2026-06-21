## ADDED Requirements

### Requirement: Video Detail UI SHALL render Bangumi rich detail sections
The desktop video detail page SHALL render poster art, title, summary, rating,
rank, collection total, episode count, tracking controls, local playback
actions, categorized staff controls, current staff-category rows,
character/CV rows, and related subject rows from `VideoDetailViewData` only.

#### Scenario: Detail page receives complete Bangumi view data
- **WHEN** detail view data includes stats, credits, characters, voice actors,
  and related subjects
- **THEN** the page renders professional Bangumi detail sections without direct
  provider, transport, JSON, token, or network access

#### Scenario: Staff table has multiple roles
- **WHEN** detail view data contains staff credits from multiple roles
- **THEN** the page groups staff by role and displays one selected role at a
  time instead of expanding every staff row at once

### Requirement: Video Detail UI SHALL keep incomplete Bangumi enrichments usable
The desktop video detail page SHALL show clear empty/error states for missing
staff, character/CV, or relation data while keeping tracking and local playback
actions available.

#### Scenario: Staff table is unavailable
- **WHEN** the detail view data contains a staff-table failure but playable
  episodes are available
- **THEN** the page shows the staff failure state and still allows episode
  playback and tracking status changes
