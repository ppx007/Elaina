# desktop-app-settings Specification

## Purpose
TBD - created by archiving change ui-milestone4-settings-and-diagnostics. Update Purpose after archive.
## Requirements
### Requirement: Settings UI SHALL toggle user configurations
The settings page SHALL allow users to modify player preferences, layout preferences, and cache sizes, persisting them to local storage.

#### Scenario: Change setting value
- **WHEN** the user changes a preference toggle (e.g., hardware acceleration) in the settings view
- **THEN** the UI writes the updated configuration value to local storage settings
- **AND** updates the active application state

### Requirement: Settings UI SHALL configure network proxy settings
The settings page SHALL provide input fields for configuring custom HTTP proxies and DNS policies.

#### Scenario: Save custom network proxy
- **WHEN** the user inputs a valid proxy host URL and saves it
- **THEN** the UI updates the proxy values in [NetworkPolicy](file:///D:/CodeWork/pkpk/lib/src/network/network_policy.dart)

