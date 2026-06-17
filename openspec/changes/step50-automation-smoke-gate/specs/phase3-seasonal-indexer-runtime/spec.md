## ADDED Requirements

### Requirement: Seasonal feed flow SHALL participate in the automation smoke gate
The seasonal feed flow SHALL support a non-UI smoke path that consumes accepted
RSS refresh items, persists normalized seasonal catalog entries, and projects
pending Bangumi match queue work.

#### Scenario: Automation smoke gate projects seasonal work
- **WHEN** the automation smoke gate refreshes a registered seasonal RSS feed
  through `SeasonalFeedFlowBootstrap`
- **THEN** accepted RSS items are converted into seasonal catalog entries,
  pending Bangumi match work is projected, and the flow returns typed success
  without relying on asynchronous listener timing, UI pages, concrete network
  clients in Domain code, RSS auto-download handoff, BT, online rule internals,
  diagnostics actions, or native player behavior
