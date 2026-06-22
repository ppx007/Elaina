## ADDED Requirements

### Requirement: RSS Engine Runtime SHALL manage auto-download rules
`RssEngineRuntime` SHALL expose feed-scoped auto-download rule projections,
draft validation, persistence, deletion, and preview without requiring UI
callers to access policy storage directly.

#### Scenario: Persist feed-scoped rule
- **WHEN** a rule draft contains a feed source, label, and at least one include
  condition
- **THEN** the runtime stores it under the default RSS auto-download policy
- **AND** the rule remains scoped to the requested feed source

#### Scenario: Reject invalid rule
- **WHEN** a rule draft contains an invalid regular expression or no include
  condition
- **THEN** the runtime returns a typed failure
- **AND** no existing rules are overwritten

### Requirement: RSS Engine Runtime SHALL execute accepted auto-download rules
`RssEngineRuntime` SHALL evaluate enabled feed-scoped rules after a successful
refresh and enqueue accepted candidates through an RSS download enqueuer.

#### Scenario: Refresh accepts matching item
- **WHEN** a refreshed feed item matches an enabled rule for an enabled feed
- **THEN** the runtime records policy evaluation and handoff state
- **AND** it asks the RSS download enqueuer to create a download task
- **AND** it records the enqueue outcome

#### Scenario: Refresh has no matching rule
- **WHEN** auto-download is enabled for a feed but no enabled rule accepts the
  item
- **THEN** the runtime records rejection or dedupe state
- **AND** it does not enqueue a download task

#### Scenario: Torrent URL requires resolution
- **WHEN** an accepted candidate points to an HTTP or HTTPS `.torrent` URL
- **THEN** the enqueuer resolves it to a local file URI before invoking the
  download runtime
- **AND** resolution failure is recorded as a failed enqueue outcome
