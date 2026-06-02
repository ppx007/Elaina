## ADDED Requirements

### Requirement: Video detail data SHALL be assembled through Domain contracts
The system SHALL expose video detail page data through Domain contracts rather than direct UI calls to providers, storage, RSS, or player engines.

#### Scenario: Detail page requests data
- **WHEN** the video detail page needs cover, summary, episodes, continue-watching state, or follow state
- **THEN** it receives a Domain view data model assembled from approved layer contracts

### Requirement: Episode selection SHALL remain playback-capability aware
The system SHALL define episode selection and continue-watching actions without bypassing playback capability checks.

#### Scenario: User selects an episode
- **WHEN** an episode is selected from the detail data
- **THEN** the action resolves playback through Domain/Playback contracts rather than provider or storage internals

### Requirement: Detail page primary actions SHALL remain limited
The system SHALL keep detail-page primary actions limited to the main viewing/following flow, with secondary actions moved behind action boundaries.

#### Scenario: Detail data exposes actions
- **WHEN** actions are derived for a video detail view
- **THEN** at most two actions are marked primary and additional operations are exposed as secondary actions
