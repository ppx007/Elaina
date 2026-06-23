## ADDED Requirements

### Requirement: RSS Engine Runtime SHALL enqueue manual feed item downloads
`RssEngineRuntime` SHALL expose a manual feed item enqueue API that accepts feed
item ids and returns a per-item report.

#### Scenario: Manual magnet item enqueue
- **WHEN** the requested feed item exposes a magnet source
- **THEN** the runtime creates an `RssDownloadCandidate`
- **AND** it asks `RssDownloadTaskEnqueuer` to enqueue the candidate
- **AND** it reports the item as accepted when the enqueuer accepts it

#### Scenario: Manual torrent URL enqueue
- **WHEN** the requested feed item exposes a torrent URL
- **THEN** the runtime passes a torrent candidate to `RssDownloadTaskEnqueuer`
- **AND** remote torrent URL resolution remains owned by the enqueuer adapter

#### Scenario: Manual download unavailable
- **WHEN** no RSS download enqueuer is configured
- **THEN** the runtime returns an unavailable action result
- **AND** it does not attempt to evaluate auto-download rules

#### Scenario: Manual batch mixed results
- **WHEN** a batch contains accepted, missing, or non-downloadable item ids
- **THEN** the runtime returns a report with per-item results
- **AND** failed items do not prevent other valid items from being enqueued

#### Scenario: Manual download source semantics
- **WHEN** RSS filtering, automatic download rules, and manual downloads decide
  whether an item is downloadable
- **THEN** they use the same shared RSS download source detection semantics
