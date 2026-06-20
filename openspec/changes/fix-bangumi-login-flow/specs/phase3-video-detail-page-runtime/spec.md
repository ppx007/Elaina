## ADDED Requirements

### Requirement: Video detail SHALL consume remote tracking status
The video detail runtime SHALL project authenticated Bangumi tracking collection
state into a provider-neutral detail tracking status without exposing provider
HTTP, auth session, or collection payload details to UI callers.

#### Scenario: Remote tracked detail is opened
- **WHEN** a detail id exists in the authenticated Bangumi anime collection
- **THEN** `VideoDetailViewData` exposes the matching planned, watching,
  completed, on-hold, or dropped tracking status
- **AND** the detail page renders that status instead of the untracked follow
  prompt
- **AND** remote-only tracked details do not execute local follow or unfollow
  mutations until a subject-collection mutation contract exists

### Requirement: Video detail overlay SHALL be a global top-level surface
The app shell SHALL route detail openings from tracking and local media entry
points through one top-level detail surface that renders above normal pages and
the playback overlay.

#### Scenario: Detail remains interactive while playback is active
- **WHEN** a user opens a tracked detail and playback becomes active
- **THEN** the detail overlay remains the top interactive surface
- **AND** closing the detail returns to the underlying page without disabling
  the active playback state
