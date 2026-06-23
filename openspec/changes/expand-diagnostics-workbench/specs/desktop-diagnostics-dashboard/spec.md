## MODIFIED Requirements

### Requirement: Diagnostics UI SHALL render system telemetry
The diagnostics page SHALL show current system telemetry and module health
using a read-only workbench snapshot that aggregates existing runtime
projections.

#### Scenario: Display application diagnostics workbench
- **WHEN** the diagnostics page is opened
- **THEN** it displays memory usage, AV sync drift, module health, event
  summaries, and capability support status
- **AND** it exposes dedicated read-only sections for playback, downloads, RSS,
  local media library, provider/network configuration, and event logs
- **AND** the UI does not mutate playback, provider, RSS, download, network, or
  storage behavior

#### Scenario: Display playback diagnostics
- **WHEN** playback state is available
- **THEN** diagnostics show lifecycle status, source URI, timeline, buffer,
  active tracks, subtitle cue counts, danmaku lane/comment counts, warnings,
  failures, and playback capability reasons from existing playback contracts
- **AND** the diagnostics page does not invoke track discovery on the refresh
  timer

#### Scenario: Isolate module sampling failures
- **WHEN** one module fails while building the workbench snapshot
- **THEN** the failed module reports its own failure state
- **AND** other module panels continue to display their latest sampled data

#### Scenario: Auto-refresh while visible
- **WHEN** the diagnostics page is visible
- **THEN** it refreshes workbench data on the configured interval
- **AND** it skips overlapping refreshes when a previous refresh is still
  running
- **AND** it preserves the latest successful data when a refresh fails

#### Scenario: Pause refresh while hidden
- **WHEN** the diagnostics page is retained by the shell but is not the active
  navigation page
- **THEN** automatic refresh is paused
- **AND** the page refreshes immediately when it becomes active again

### Requirement: Diagnostics UI SHALL list timeline events
The diagnostics page SHALL list system events and warning logs with filtering
and drill-in payload inspection.

#### Scenario: Filter and inspect event log
- **WHEN** diagnostics events are available
- **THEN** the UI renders recent events in newest-first order with timestamp,
  source module, severity, event type, and redacted details
- **AND** the user can filter by module, severity, event type, or payload text
- **AND** selecting an event shows its payload details without mutating
  diagnostics storage
