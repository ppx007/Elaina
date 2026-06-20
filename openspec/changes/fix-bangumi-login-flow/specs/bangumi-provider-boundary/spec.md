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
