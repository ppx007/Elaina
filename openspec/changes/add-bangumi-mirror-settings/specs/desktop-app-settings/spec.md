## ADDED Requirements

### Requirement: Settings UI SHALL configure Bangumi mirror usage
The settings page SHALL expose a Bangumi mirror switch and separate API and
image mirror URL fields.

#### Scenario: User enables a valid mirror
- **WHEN** the user provides valid API and image mirror base URLs and enables
  the Bangumi mirror switch
- **THEN** the app persists the mirror as enabled

#### Scenario: User attempts to enable an invalid mirror
- **WHEN** the API or image mirror URL is empty, not absolute http/https, or
  includes query or fragment data
- **THEN** the settings page keeps the mirror disabled and shows the validation
  error
