## ADDED Requirements

### Requirement: Feed fetch responses SHALL support not-modified refreshes
Feed fetch responses SHALL represent HTTP not-modified outcomes so RSS runtime
refresh can update cursor freshness without invoking feed parsers or emitting
new items.

#### Scenario: Feed source is not modified
- **WHEN** a concrete feed fetcher receives a not-modified response for a
  request with ETag or Last-Modified validators
- **THEN** the RSS engine returns a successful refresh with no accepted items,
  preserves cursor metadata, and does not call `FeedParser`

### Requirement: Concrete parser failures SHALL become typed RSS refresh failures
RSS engine refresh SHALL normalize concrete parser failures into typed refresh
and runtime failures instead of leaking raw XML/parser exceptions.

#### Scenario: Concrete parser rejects malformed XML
- **WHEN** a concrete RSS or Atom parser reports a malformed feed through
  provider-normalized failure semantics
- **THEN** runtime refresh returns a typed parser failure preserving the
  failure message without exposing parser package exceptions to UI or
  downstream consumers
