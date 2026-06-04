## Why

Step 16 needs the RSS Engine to move beyond bootstrap Provider-layer feed contracts into a durable, Domain-facing refresh pipeline. The just-archived subtitle provider cache slice explicitly left RSS Engine and seasonal indexing out of scope, making this the next plan-aligned contract gap before YucWiki seasonal work.

## What Changes

- Add an RSS engine contract for source registration, conditional fetch metadata, parser handoff, deduplication, feed item persistence, and update emission.
- Add Storage-layer feed source, feed item, feed cursor, and deduplication responsibilities so RSS state does not live in Provider implementations.
- Refine RSS foundation requirements so RSS/Atom fetch, parse, schedule, dedupe, and persistence are composed through Domain orchestration without source-specific scraping.
- Refine ProviderGateway requirements for feed fetchers to preserve cache validators and gateway-normalized failure semantics.
- Keep YucWiki seasonal normalization, RSS auto-download rules, concrete HTTP fetch implementation, UI RSS pages, and BT integration out of scope.

## Capabilities

### New Capabilities

- `rss-engine-contract`: Domain and Storage contracts for RSS/Atom source refresh, deduplication, persistence, and update emission.

### Modified Capabilities

- `rss-engine-foundation`: Adds durable feed pipeline orchestration requirements beyond the bootstrap provider contracts.
- `local-storage-foundation`: Adds feed source/item/cursor/deduplication state as first-class Storage responsibilities.
- `provider-gateway`: Clarifies that RSS feed fetchers preserve gateway cache validators and normalized provider failures.

## Impact

Affected code includes RSS provider contracts, new Domain RSS orchestration contracts, Storage foundation records/stores, runtime/checker validation, and contract tests. No concrete RSS HTTP client, YucWiki seasonal consumer, auto-download policy implementation, UI, or BT streaming behavior is part of this proposal.
