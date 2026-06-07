## 1. Storage and Policy Records

- [ ] 1.1 Add Storage-layer records for RSS auto-download policies, feed-scoped policy activation, declarative matcher rules, evaluation history, accepted candidates, rejected candidates, deduplication state, and enqueue outcomes.
- [ ] 1.2 Add an `RssAutoDownloadPolicyStore` interface and deterministic in-memory store following existing Storage contract patterns.
- [ ] 1.3 Expose RSS auto-download persistence through `StorageDomain`, `StorageFoundation`, and public barrel exports.

## 2. Policy Evaluation and BT Handoff Contracts

- [ ] 2.1 Extend RSS auto-download policy contracts with typed registration, evaluation, acceptance, rejection, deduplication, disable, and BT handoff outcomes/failures.
- [ ] 2.2 Implement a deterministic policy evaluator that consumes accepted RSS Engine feed items, declarative matcher records, feed scope, global enablement state, and durable dedupe history without creating a second RSS engine.
- [ ] 2.3 Add engine-neutral BT task handoff read models for accepted RSS candidates, preserving policy identity, feed item identity, source URI, dedupe key, and enqueue state without concrete torrent engine APIs.

## 3. Invalidation, Capability Gating, and Boundaries

- [ ] 3.1 Add RSS automation invalidation events for policy changes, feed item evaluation, candidate acceptance/rejection, deduplication state changes, and enqueue handoff outcomes.
- [ ] 3.2 Add or refine capability gating so RSS auto-download support, disabled state, unsupported reasons, and optional automation behavior remain explicit.
- [ ] 3.3 Update Phase 6 checker rules and documentation to enforce Step 26 boundaries: no duplicate RSS engine, no concrete torrent engine, no yuc.wiki special case, no online rule runtime, no WebView/network/diagnostics behavior, and no mandatory automation startup.

## 4. Verification

- [ ] 4.1 Add focused tests for policy storage, typed matcher evaluation, include/exclude precedence, dedupe rejection, accepted candidate handoff, disabled automation rejection, and invalidation publication.
- [ ] 4.2 Update runtime validation to exercise the RSS auto-download policy contract and guard against forbidden dependencies.
- [ ] 4.3 Run `openspec validate "rss-auto-download-policy-contract" --strict`, `openspec validate --all`, `dart analyze`, focused tests, runtime checks, and Phase 6 checker scripts.
