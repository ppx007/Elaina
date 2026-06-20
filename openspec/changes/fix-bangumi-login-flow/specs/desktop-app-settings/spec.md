## ADDED Requirements

### Requirement: Settings UI SHALL connect Bangumi token entry to auth refresh
The settings page SHALL submit Bangumi access-token changes through an injected
login boundary that can persist and validate auth state before the application
profile projection is refreshed.

#### Scenario: Token is accepted
- **WHEN** the user enters a valid Bangumi access token
- **THEN** the settings UI invokes the Bangumi login boundary
- **AND** the app shell refreshes the Bangumi profile so account labels and
  avatars can update without restarting the app
