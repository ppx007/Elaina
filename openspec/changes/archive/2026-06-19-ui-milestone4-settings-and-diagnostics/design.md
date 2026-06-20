## Context

This design outlines the settings form structure and the diagnostics telemetry center integration. It provides a way for users to configure preferences and view system reports.

## Goals / Non-Goals

**Goals:**
- Construct the `SettingsPage` containing sections for general, network, and player options.
- Construct the `DiagnosticsPage` displaying active system status, capabilities, and timeline logs.
- Connect widgets to preference storage and [DiagnosticsCenterRuntime](file:///D:/CodeWork/elaina/lib/src/foundation/diagnostics/diagnostics_center_runtime.dart).

**Non-Goals:**
- Implementing remote logging or analytics reports.

## Decisions

### 1. Auto-save Configuration States
- **Choice**: Persist setting configurations immediately upon user change (toggling a switch or finishing text input) rather than using a global "Apply" button.
- **Rationale**: Reduces friction for the user and prevents unsaved changes when navigating away.

### 2. Cap Diagnostic Event Logs Size
- **Choice**: Limit the Diagnostics Page display list to the latest 100 timeline events.
- **Rationale**: Prevents unbounded memory growth in the UI layer during long playback sessions.

## Risks / Trade-offs

- **[Risk] Rapid diagnostic event logging blocks the UI thread** → **Mitigation**: The diagnostics center handles event aggregation asynchronously. The UI is updated periodically or when navigating to the page.
