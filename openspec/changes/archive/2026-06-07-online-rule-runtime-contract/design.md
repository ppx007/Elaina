## Context

Phase 6 Steps 26-30 move Elaina from playback/data foundation into optional automation and extension contracts. Step 27 is online rule sources: declarative source manifests describe how to extract search results, detail metadata, episode lists, and playable-source candidates from provider-managed pages.

The bootstrap `online-rule-runtime` spec already requires declarative manifests, CSS selector / XPath 1.0 / regex extraction, page-type separation, ProviderGateway network access, and optionality. It does not yet define durable manifest/rule/evaluation records, typed validation and evaluation outcomes, normalized read models, invalidation events, runtime validation, or checker coverage. This change must deepen those contracts without implementing a concrete crawler, scraper, JavaScript/WASM engine, WebView challenge flow, network resolver, diagnostics action, or UI.

## Goals / Non-Goals

**Goals:**
- Define storage-backed online rule runtime records for manifests, versions, rule sets, validation issues, evaluation snapshots, retrieval outcomes, and capability state.
- Replace implicit validation/evaluation failures with typed registration, validation, refresh, retrieval, extraction, unsupported-operation, disable, and capability outcomes.
- Provide deterministic contract scaffolding for evaluating declared CSS selector, XPath 1.0 intent, and regex operations against supplied documents.
- Model search, detail, episode, and playable-source outputs as normalized Domain-facing read models.
- Require rule-source manifest/page retrieval to route through ProviderGateway and provider-scoped network policy contracts.
- Publish invalidation events when manifests change, validation state changes, evaluations run, unsupported operations are recorded, or capability state changes.
- Add tests, runtime validation, checker rules, and docs that prove Step 27 remains optional and extension-neutral.

**Non-Goals:**
- No concrete online crawler, scraper scheduler, page fetcher implementation, browser automation, HTML parser dependency, JavaScript/WASM/scriptlet execution, or arbitrary code execution.
- No WebView challenge handling or automatic captcha solving; Step 28 owns manual session backfill.
- No concrete DNS resolver, proxy implementation, VPN/TUN/kernel routing behavior, or system-wide network guarantee.
- No yuc.wiki-specific special case and no source-specific parsing hardcoded into Domain/UI layers.
- No requirement that online rules be installed or enabled for local playback, manual URL playback, BT virtual stream playback, RSS refresh, media-library use, or core playback startup.

## Decisions

1. **Use versioned declarative manifests as the source of truth.**
   - Decision: online rule sources are persisted as manifests with source identity, version, checksum/update metadata, target-specific rule sets, validation state, and capability state.
   - Rationale: manifests are inspectable, cacheable, testable, and safe to update without embedding executable code.
   - Alternative considered: source-specific Dart providers for each website. Rejected because it hardcodes providers and bypasses the extension model.

2. **Keep extraction operations declarative.**
   - Decision: Step 27 contracts represent CSS selector, XPath 1.0, and regex extraction intent and report unsupported operations for JavaScript, WASM, scriptlets, arbitrary code, unsupported selectors, and unsafe regex.
   - Rationale: this preserves a safe baseline while leaving JS/WASM as future extension points behind explicit capability gating.
   - Alternative considered: embed a JS/WASM runtime now. Rejected because it changes the threat model and belongs to a later extension slice.

3. **Separate retrieval from evaluation.**
   - Decision: ProviderGateway/network-policy contracts govern manifest updates and page retrieval, while the runtime evaluates already supplied page documents.
   - Rationale: this prevents online-rule runtime from owning transport logic and keeps SSRF/rate-limit/retry semantics centralized.
   - Alternative considered: let the runtime fetch URLs directly. Rejected because it violates ProviderGateway and Network layer boundaries.

4. **Return normalized read models per target type.**
   - Decision: search, detail, episode, and playable-source evaluations return typed read models rather than loosely keyed maps as the final contract surface.
   - Rationale: normalized outputs make downstream Domain behavior testable without relying on source-specific selectors or UI assumptions.
   - Alternative considered: expose raw extraction maps only. Rejected because it would push parsing semantics into consumers.

5. **Publish invalidation through CacheInvalidationBus.**
   - Decision: manifest changes, validation updates, evaluation snapshots, unsupported operations, and capability changes publish explicit invalidation events.
   - Rationale: existing contract slices use event-driven invalidation instead of direct cross-layer callbacks.
   - Alternative considered: direct callbacks into diagnostics/UI. Rejected because diagnostics and UI are outside this contract slice.

## Risks / Trade-offs

- **Risk: declarative extraction looks like a full scraper promise.** → Mitigation: keep this slice to contracts, supplied documents, typed outputs, and checker-enforced non-goals.
- **Risk: online source parsing becomes part of playback startup.** → Mitigation: capability-gate online rules and explicitly preserve local/manual/BT/RSS/library flows when unsupported.
- **Risk: regex or selector semantics become unsafe or too broad.** → Mitigation: typed unsupported-operation outcomes and runtime checks reject unbounded regex/script-like operations.
- **Risk: Step 28 WebView behavior leaks into Step 27.** → Mitigation: checker rules forbid WebView/challenge/captcha/session-backfill behavior in the online rule runtime slice.

## Migration Plan

1. Add `online-rule-runtime-contract` specs and deltas for affected specs.
2. Extend Dart contracts with online rule storage records/store, typed outcomes/failures, deterministic extraction scaffolding, normalized read models, ProviderGateway/network handoff records, and invalidation events.
3. Update public exports, runtime checks, focused tests, Phase 6 docs, and automation checker rules.
4. Validate with OpenSpec, analyzer, focused tests, runtime checks, and Phase 6 checker scripts.

Rollback is straightforward because this change introduces declarative contract/value/state scaffolding only; no concrete crawler, JS/WASM engine, network resolver, WebView flow, or external dependency is introduced.

## Open Questions

- None blocking for the contract slice. Concrete selector engine choice, HTML parser dependency, manifest distribution format, JS/WASM extension sandbox, WebView session handoff, source marketplace UI, and diagnostics presentation are intentionally deferred.
