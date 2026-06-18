## MODIFIED Requirements

### Requirement: Video detail runtime SHALL execute detail actions through existing Domain contracts
The video detail runtime SHALL execute continue playback, episode selection,
follow, unfollow, open-binding, and refresh-metadata actions through existing
Domain contracts and explicit results instead of direct UI, provider, storage,
native-player shortcuts, or raw repository load exceptions.

#### Scenario: Continue playback is requested
- **WHEN** continue playback is requested for a detail with a local media identity and continue-watching state
- **THEN** the runtime resolves playback through the playback source handoff contract and reports success or a normalized action failure

#### Scenario: Detail action cannot load view data
- **WHEN** any detail action needs repository data and the repository cannot load
  the requested detail
- **THEN** the action returns a typed `VideoDetailActionResult.failed` result and
  does not leak the repository exception to the caller
