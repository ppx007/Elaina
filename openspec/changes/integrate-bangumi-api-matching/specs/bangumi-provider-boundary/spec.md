## ADDED Requirements

### Requirement: Bangumi desktop API usage SHALL follow published client guidance
The Bangumi concrete API client SHALL identify Elaina with a non-generic
User-Agent containing owner, application name, version, platform, and project
home page, and SHALL use official API/OAuth endpoints rather than Bangumi
site-local component scripts.

#### Scenario: Provider sends a Bangumi API request
- **WHEN** Elaina sends a Bangumi API request from the concrete provider client
- **THEN** the request includes a project-identifying User-Agent and is routed
  through `ProviderGateway`
- **AND** the implementation does not load Bangumi garage component scripts,
  access site cookies, or scrape HTML pages for API behavior

### Requirement: Bangumi OAuth application secrets SHALL remain outside source
The system SHALL keep OAuth client secrets and refreshable credentials outside
source-controlled code and documentation while allowing a configured access
token to enrich session and progress operations.

#### Scenario: Repository is published
- **WHEN** the repository is committed or pushed
- **THEN** no Bangumi App Secret, user access token, refresh token, or derived
  credential is present in source-controlled files
- **AND** unauthenticated metadata lookup and local playback remain available
