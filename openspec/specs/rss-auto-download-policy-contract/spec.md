# rss-auto-download-policy-contract Specification

## Purpose
TBD - created by archiving change rss-auto-download-policy-contract. Update Purpose after archive.
## Requirements
### Requirement: RSS auto-download policy contract SHALL persist declarative automation state
The system SHALL define durable RSS auto-download records for global and feed-scoped policies, matcher rules, evaluation history, accepted candidates, rejected candidates, deduplication state, and enqueue outcomes without storing concrete torrent engine handles, RSS parser instances, UI state, or background service resources.

#### Scenario: Automation state is restored
- **WHEN** RSS auto-download policies and evaluation history are written to Storage
- **THEN** later feed refresh handling can restore policy intent and dedupe decisions without depending on a concrete download engine implementation

### Requirement: RSS auto-download policy contract SHALL evaluate feed items deterministically
The system SHALL define deterministic policy evaluation using existing RSS Engine feed item data, declarative matcher rules, feed scope, global enablement state, dedupe history, and explicit rejection reasons.

#### Scenario: Feed item matches a policy
- **WHEN** an accepted RSS Engine feed item satisfies a registered auto-download policy matcher
- **THEN** the policy evaluator returns a typed accepted-candidate outcome with policy identity and normalized source metadata before any BT task is enqueued

### Requirement: RSS auto-download policy contract SHALL expose typed automation outcomes
The system SHALL return typed policy registration, evaluation, acceptance, rejection, deduplication, disable, and BT handoff outcomes for RSS automation actions instead of relying on nullable candidates, thrown concrete adapter exceptions, or implicit duplicate checks.

#### Scenario: Feed item is already handled
- **WHEN** a feed item has an accepted candidate key already present in RSS auto-download history
- **THEN** the evaluation outcome contains a typed deduplicated result with an explicit reason and no new BT task handoff is requested

### Requirement: RSS auto-download policy contract SHALL hand off through engine-neutral BT requests
The system SHALL represent accepted RSS candidates as engine-neutral BT task creation requests with source metadata, policy identity, feed item identity, and candidate dedupe key while keeping concrete torrent engines outside RSS automation.

#### Scenario: Candidate is accepted for enqueue
- **WHEN** RSS auto-download accepts a magnet or torrent candidate
- **THEN** it prepares a BT task handoff through Streaming-layer task contracts without importing libtorrent, sockets, FFI, or concrete download adapter APIs

### Requirement: RSS auto-download policy contract MUST remain optional and extension-neutral
The system MUST keep concrete torrent engines, libtorrent bindings, RSS fetch/parse duplication, online source crawlers, yuc.wiki-specific special cases, JavaScript/WASM execution, WebView challenge handling, DNS/network policy behavior, diagnostics actions, Flutter UI, and mandatory automation startup outside the RSS auto-download policy contract slice.

#### Scenario: Automation checker runs
- **WHEN** boundary checks scan Step 26 contracts
- **THEN** no concrete torrent engine, duplicate RSS engine, online rule runtime, WebView challenge flow, network policy implementation, diagnostics action, or mandatory automation dependency is required by the RSS auto-download contract

