## Why

Users need the ability to customize application preferences (e.g. proxy settings, DNS policies) and view full diagnostics telemetry (including AV sync offset logs and rule engine evaluations) to troubleshoot failures. Implementing the Settings and Diagnostics screens is required to achieve the fourth frontend milestone.

## What Changes

- **Settings Screen**: Create the `SettingsPage` widget to configure player preferences, network DNS rules, and local directories.
- **Settings Store Integration**: Connect settings toggles to the respective local storage preference contracts.
- **Diagnostics Dashboard**: Create the `DiagnosticsPage` widget to present timeline event tables, capability verification states, and debug run logs.
- **Diagnostics Center Integration**: Connect the screen to [DiagnosticsCenterRuntime](file:///D:/CodeWork/elaina/lib/src/foundation/diagnostics/diagnostics_center_runtime.dart) to display telemetry.

## Capabilities

### New Capabilities
- `desktop-app-settings`: Supports toggling user preferences, configuring DNS proxies, and setting up directories.
- `desktop-diagnostics-dashboard`: Displays system logs, AV sync guard status, timeline overlays, and capability matrices.

### Modified Capabilities
<!-- No requirement changes to existing core specs. -->
