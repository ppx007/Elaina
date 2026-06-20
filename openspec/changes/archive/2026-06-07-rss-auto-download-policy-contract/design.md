## Context

Phase 6 Steps 26-30 move Elaina from playback/data foundation into optional automation and extension contracts. Step 26 is RSS auto-download: feed items already accepted by the RSS Engine can be evaluated by declarative policies and, when accepted, handed to BT task creation through engine-neutral Streaming contracts.

The bootstrap `rss-auto-download-policy` spec already requires reuse of existing feed contracts, declarative matching, durable history, engine-neutral BT enqueue, and optional capability gating. It does not yet define durable policy/matcher/history records, typed evaluation and enqueue outcomes, deterministic matching semantics, invalidation events, or checker/runtime coverage. This change must deepen those contracts without creating a second feed engine, special-casing yuc.wiki, importing concrete torrent engines, or making automation part of the core playback loop.

## Goals / Non-Goals

**Goals:**
- Define storage-backed RSS auto-download policy records for global/feed-scoped policies, matcher rules, evaluation history, accepted/rejected candidates, and enqueue outcomes.
- Replace implicit policy decisions with typed registration, evaluation, acceptance, rejection, deduplication, disable, and BT handoff outcomes/failures.
- Provide deterministic policy evaluation from existing `FeedItem` metadata after RSS parsing and deduplication.
- Model accepted download candidates as engine-neutral BT task creation requests, not concrete torrent engine calls.
- Publish invalidation events when policies change, feed items are evaluated, candidates are accepted/rejected, dedup state changes, or enqueue outcomes are recorded.
- Add tests, runtime validation, checker rules, and docs that prove Step 26 remains optional and extension-neutral.

**Non-Goals:**
- No concrete torrent engine, libtorrent binding, socket implementation, long-running background service, or BT execution behavior.
- No second RSS fetch/parse scheduler and no duplicate RSS engine.
- No online source parser, crawler, yuc.wiki-specific scraper, CSS/XPath rule runtime, JavaScript/WASM execution, WebView challenge handling, DNS/network policy behavior, diagnostics action, or Flutter UI.
- No requirement that RSS automation be installed or enabled for local playback, media-library use, manual BT tasks, or core playback startup.

## Decisions

1. **Consume accepted feed items, not feed sources directly.**
   - Decision: RSS auto-download policies evaluate `FeedItem`-level Domain data emitted by the RSS Engine after fetch, parse, and feed deduplication.
   - Rationale: Step 26 must reuse the RSS Engine rather than reimplementing feed refresh or source-specific parsing.
   - Alternative considered: give auto-download policies their own fetcher/parser. Rejected because it duplicates Step 16 and violates the bootstrap requirement.

2. **Use declarative matcher records.**
   - Decision: matcher rules will be persisted as typed/declarative records for title, group, episode, season, resolution, size, category, include terms, exclude terms, regex/glob intent, and metadata predicates with explicit AND/OR/NOT semantics.
   - Rationale: declarative records are inspectable, testable, and safe to store without embedding executable scripts.
   - Alternative considered: store executable callbacks or scripting expressions. Rejected because Phase 6 forbids JavaScript/WASM/arbitrary execution for this slice.

3. **Persist evaluation history before enqueue handoff.**
   - Decision: policy evaluation records will capture accepted/rejected/deduped outcomes before any BT handoff result is recorded.
   - Rationale: durable history is required to prevent duplicate tasks across refreshes and restarts, even when enqueue later fails or is unavailable.
   - Alternative considered: dedupe only after BT task creation succeeds. Rejected because repeated refreshes could enqueue duplicates after transient failures.

4. **Represent BT handoff as data.**
   - Decision: accepted RSS candidates produce engine-neutral BT task create requests with source metadata and policy identity.
   - Rationale: Domain automation may ask BT task core to create work, but must not import libtorrent or concrete adapter APIs.
   - Alternative considered: call a download engine adapter directly from RSS automation. Rejected because Provider/Domain automation must not bypass Streaming contracts.

5. **Publish automation events through `CacheInvalidationBus`.**
   - Decision: policy changes, item evaluation, candidate acceptance/rejection, dedup state, and enqueue outcomes publish invalidation events.
   - Rationale: existing contract slices use event-driven invalidation instead of direct cross-layer callbacks.
   - Alternative considered: direct callbacks into diagnostics, UI, or BT task views. Rejected because those layers are outside this contract slice.

## Risks / Trade-offs

- **Risk: declarative matcher semantics become too broad.** → Mitigation: keep this slice to typed matcher intent and deterministic evaluation; defer online-rule engines and scripting to later steps.
- **Risk: automation appears to promise background download support on every platform.** → Mitigation: capability-gate automation and handoff only; platform background behavior remains a future concrete adapter concern.
- **Risk: duplicate prevention conflicts with manual BT task creation.** → Mitigation: persist RSS policy identity and candidate keys separately from manual task state, and only dedupe policy-originated candidates through explicit history.
- **Risk: yuc.wiki receives special treatment because current seasonal RSS uses it.** → Mitigation: model it as a normal `FeedSource`/`FeedItem` producer and forbid source-specific scraper logic in checker rules.

## Migration Plan

1. Add `rss-auto-download-policy-contract` specs and deltas for affected specs.
2. Extend Dart contracts with RSS automation storage records/store, typed outcomes/failures, deterministic matcher/evaluator, BT handoff read models, and invalidation events.
3. Update public exports, runtime checks, focused tests, Phase 6 docs, and automation checker rules.
4. Validate with OpenSpec, analyzer, focused tests, runtime checks, and Phase 6 checker scripts.

Rollback is straightforward because this change introduces declarative contract/value/state scaffolding only; no background service, concrete torrent adapter, or external dependency is introduced.

## Open Questions

- None blocking for the contract slice. Concrete regex/glob implementation details, user-facing policy editing UI, platform background scheduling, diagnostics display, and online-source automation are intentionally deferred.
