## ADDED Requirements

### Requirement: Media library state SHALL be consumable by video detail runtime
Media library continue-watching and provider-binding contracts SHALL be consumable by the video detail runtime without requiring media scanning, catalog import, storage implementation details, provider runtime internals, gateway requests, network resources, or UI state.

#### Scenario: Detail runtime reads continue-watching state
- **WHEN** a detail id resolves to local media with playback history
- **THEN** the detail runtime can include continue-watching state from media-library contracts without owning history persistence or playback progress recording

### Requirement: User-confirmed bindings SHALL drive video detail follow state
User-confirmed provider bindings SHALL drive video detail follow state and SHALL outrank automatic bindings when the detail runtime derives follow/unfollow actions.

#### Scenario: Detail binding is user-confirmed
- **WHEN** a local media item has a user-confirmed provider binding for the selected metadata provider
- **THEN** the detail runtime exposes a followed state and does not replace it with lower-confidence automatic metadata matches
