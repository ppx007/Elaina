## ADDED Requirements

### Requirement: Bangumi OAuth start SHALL use official authorization endpoints
The concrete Bangumi provider boundary SHALL expose only provider-safe helpers
for building official OAuth authorization requests and SHALL NOT expose client
secrets, user credentials, HTTP transports, or raw OAuth payloads to UI code.

#### Scenario: User starts Bangumi login
- **WHEN** the UI asks to start Bangumi login through a Domain login contract
- **THEN** the runtime opens a `https://bgm.tv/oauth/authorize` authorization
  URI built with the public Elaina client id
- **AND** the UI does not import the concrete Bangumi API client, transport,
  OAuth endpoint constants, or credential payload types

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
