## ADDED Requirements

### Requirement: Bangumi login start SHALL open token acquisition without callback deployment
The concrete Bangumi provider boundary SHALL expose only provider-safe helpers
for opening the Bangumi token acquisition page and SHALL NOT expose client
secrets, user credentials, HTTP transports, or raw OAuth payloads to UI code.

#### Scenario: User starts Bangumi login
- **WHEN** the UI asks to start Bangumi login through a Domain login contract
- **THEN** the runtime opens the Bangumi token acquisition page in the system
  browser so the user can copy an access token into settings
- **AND** the UI does not import the concrete Bangumi API client, transport,
  OAuth endpoint constants, callback server code, or credential payload types

### Requirement: Bangumi manual token login SHALL validate session state
The Bangumi login flow SHALL treat a manually entered access token as signed in
only after the existing Bangumi auth provider successfully returns the current
session.

#### Scenario: User enters an access token
- **WHEN** a user submits a Bangumi access token in settings
- **THEN** the runtime stores the trimmed token, requests the current session
  through `BangumiAuthProvider`, and refreshes the shared profile projection on
  success
- **AND** unauthenticated or failed validation is reported without requiring
  playback, local media, RSS, downloads, or provider matching to fail

### Requirement: Bangumi tracking collection SHALL refresh through provider runtime
Authenticated Bangumi tracking data SHALL be loaded through a provider/domain
boundary instead of being inferred only from local media bindings or fetched
directly by UI code.

#### Scenario: Tracking page refreshes after login
- **WHEN** an authenticated user opens or refreshes the Bangumi tracking page
- **THEN** the runtime requests the user's anime collection through the
  registered Bangumi provider runtime
- **AND** collection statuses are mapped from Bangumi collection types into
  planned, watching, completed, on-hold, and dropped tracking states
- **AND** the UI does not import the concrete Bangumi API client, transport, raw
  HTTP request types, or token payload types

### Requirement: Remote Bangumi tracking entries SHALL open provider-backed details
Bangumi tracking entries that do not have local media bindings SHALL still open
a detail page backed by Bangumi subject metadata and episode list data.

#### Scenario: User opens a remote-only tracking entry
- **WHEN** the user selects a Bangumi tracking entry without local media
- **THEN** the detail runtime loads the Bangumi subject and episode list through
  the registered provider runtime
- **AND** the detail page displays the subject title, summary, cover art when
  available, and ordered episode entries
- **AND** missing local media disables playback for those episode entries
  without preventing the detail page from opening
