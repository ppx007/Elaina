## ADDED Requirements

### Requirement: Settings Page SHALL expose read-only app information
The settings page SHALL include an About section for app identity and reference
information without treating those values as mutable preferences.

#### Scenario: User opens About section
- **WHEN** the user selects the About section in settings
- **THEN** the page displays the application name, code name, version, and
  project positioning
- **AND** it displays the project repository URL
- **AND** it displays reference repositories or public project pages for core
  upstream dependencies and services
- **AND** it does not write any settings preference merely by opening or viewing
  the section

#### Scenario: About information is stable for testing
- **WHEN** widget tests need to locate the About section and its repository list
- **THEN** the UI provides stable element ids rather than relying only on
  localized display text
