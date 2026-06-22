## MODIFIED Requirements

### Requirement: Settings UI SHALL toggle user configurations
The settings page SHALL allow users to modify global user configurations that
are consumed by the running app, including theme mode, Bangumi account settings,
Bangumi mirror settings, network policy settings, and local media library
folders.

#### Scenario: Change theme mode
- **WHEN** the user selects follow-system, light, or dark theme mode in Settings
- **THEN** the app updates the active theme mode
- **AND** persists the selected mode for the next launch

#### Scenario: Configure media library folders
- **WHEN** the user adds, replaces, or removes a media library folder in Settings
- **THEN** the app persists the updated `media_library_roots` preference
- **AND** the same folder preference encoding is used by the local media library
  page

#### Scenario: Hide ineffective settings
- **WHEN** a preference is not consumed by runtime behavior
- **THEN** the settings page SHALL NOT expose it as a configurable option

### Requirement: Settings UI SHALL configure network proxy settings
The settings page SHALL provide explicit save actions for custom HTTP proxy and
DNS policy configuration.

#### Scenario: Save custom network proxy
- **WHEN** the user edits the proxy URL field
- **THEN** the app does not persist the new proxy value until the user invokes
  the save action
- **AND** the save action updates the local network policy settings

#### Scenario: Save DNS policy
- **WHEN** the user edits the DNS policy field
- **THEN** the app does not persist the new DNS value until the user invokes the
  save action
- **AND** the save action updates the local network policy settings

## ADDED Requirements

### Requirement: Settings UI SHALL manage Bangumi account and mirror settings
The settings page SHALL allow the user to open the Bangumi OAuth authorization
page, save an access token, and configure optional Bangumi API and image mirror
base URLs.

#### Scenario: Save Bangumi token
- **WHEN** the user submits an access token
- **THEN** the app validates it through the Bangumi login controller when one is
  available
- **AND** refreshes the current Bangumi auth state after a non-failed result

#### Scenario: Enable valid Bangumi mirror
- **WHEN** the user provides valid API and image mirror base URLs and enables
  the mirror switch
- **THEN** the app persists the mirror URLs
- **AND** persists the mirror as enabled

#### Scenario: Reject invalid Bangumi mirror
- **WHEN** either mirror URL is missing, not absolute http/https, or includes a
  query or fragment
- **THEN** the settings page keeps the mirror disabled
- **AND** shows the validation error
