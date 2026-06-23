## MODIFIED Requirements

### Requirement: Diagnostics UI SHALL render system telemetry
The diagnostics page SHALL show the current capability matrix, active memory
usage, AV sync guard offset reports, event counts, and charted local
diagnostics summaries.

#### Scenario: Display telemetry dashboard
- **WHEN** the diagnostics page is opened
- **THEN** it displays current memory usage, AV sync drift, event totals,
  warning/error counts, capability support status, and local chart summaries
- **AND** the charts are derived from `DiagnosticsRuntime` projections or
  page-local telemetry samples
- **AND** the UI remains read-only and does not mutate playback, provider, RSS,
  download, network, or storage behavior

#### Scenario: Auto-refresh while visible
- **WHEN** the diagnostics page is visible
- **THEN** it refreshes diagnostics data on the configured interval
- **AND** it skips overlapping refreshes when a previous refresh is still
  running
- **AND** it preserves the latest successful data when a refresh fails

#### Scenario: Pause refresh while hidden
- **WHEN** the diagnostics page is retained by the shell but is not the active
  navigation page
- **THEN** automatic refresh is paused
- **AND** the page refreshes immediately when it becomes active again

### Requirement: Diagnostics UI SHALL list timeline events
The diagnostics page SHALL list system events and warning logs chronologically
in a scrollable dense table.

#### Scenario: Render event log table
- **WHEN** diagnostics events are available
- **THEN** the UI renders recent events in newest-first order with timestamp,
  source module, severity, event type, and redacted details
- **AND** the same events contribute to severity and source-module chart
  summaries
