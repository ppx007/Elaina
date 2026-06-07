## Context

Phase 5 Steps 22-24 deepened video enhancement, AV sync guard, and advanced caption contracts into durable, typed, implementation-neutral slices. Step 25 is the remaining Phase 5 item: optional fallback from the primary player adapter to VLC or another secondary adapter when normalized playback failures are fallback-compatible.

The bootstrap `fallback_adapter.dart` already defines fallback ids, failure kinds, adapter candidates, fallback selections, hidden capabilities, and a `PlaybackFallbackStrategy` interface, but it still returns nullable selection state and has no durable registration, selection history, latest fallback state metadata, invalidation events, deterministic evaluator, or focused tests. This change must keep fallback optional and adapter-neutral while giving future concrete VLC/native adapters a stable contract to implement.

## Goals / Non-Goals

**Goals:**
- Define storage-backed fallback adapter records for candidate registration, active fallback configuration, selection history, and latest fallback strategy state.
- Replace nullable fallback selection semantics with typed registration, evaluation, selection, disable, and capability-reevaluation outcomes/failures.
- Provide deterministic fallback evaluation that uses normalized playback failures, source compatibility, candidate priority, capability matrix reports, and hidden capability reasons.
- Publish fallback invalidation events when registration, capability evaluation, selection, or fallback state changes.
- Keep fallback capability support and hidden capability differences explicit so UI can remain capability-driven.
- Add tests, runtime validation, checker rules, and docs that prove Step 25 remains optional and implementation-neutral.

**Non-Goals:**
- No concrete VLC binding, VLC package, native plugin, platform player implementation, FFI, media-kit/libmpv bridge, or fallback adapter executable implementation.
- No Flutter widget tree, playback UI rendering, diagnostics center integration, DNS/network policy, RSS automation, online rule runtime, WebView handling, or Phase 6 provider automation.
- No mandatory VLC dependency and no requirement that core playback needs any secondary adapter installed.
- No cross-layer UI dependency on VLC, MPV, or fallback internals.

## Decisions

1. **Persist fallback intent and history, not concrete adapter handles.**
   - Decision: fallback storage records will capture adapter ids, display metadata, priority, declared capability state, active fallback configuration, selection history, and latest strategy state metadata.
   - Rationale: restart-safe fallback preferences and audit history are useful without binding storage to native objects or platform resources.
   - Alternative considered: store concrete adapter instances or native handles. Rejected because it violates adapter replaceability and storage isolation.

2. **Use typed outcomes instead of nullable selection.**
   - Decision: fallback registration, evaluation, selection, disable, and capability-reevaluation flows return explicit success/failure outcomes with normalized failure kinds and reason strings.
   - Rationale: nullable `FallbackSelection?` cannot distinguish no candidate, unsupported source, disabled fallback, incompatible failure, or capability-hidden selection.
   - Alternative considered: keep the bootstrap nullable API and document meanings. Rejected because it is not testable enough for Phase 5 contract depth.

3. **Evaluate fallback from normalized playback contracts only.**
   - Decision: deterministic fallback strategy consumes `PlaybackSource`, normalized fallback failure data, registered candidate metadata, and `PlaybackCapabilityMatrix` rows; it must not inspect MPV/libmpv/VLC/native errors.
   - Rationale: fallback must remain behind `PlayerAdapter` boundaries and work for future non-VLC secondary adapters.
   - Alternative considered: model VLC-specific error codes now. Rejected because concrete VLC integration is intentionally out of scope.

4. **Represent capability hiding as data.**
   - Decision: `FallbackSelection` continues to carry hidden capabilities, and the deepened contract adds explicit capability reevaluation outcomes and invalidation events.
   - Rationale: UI should hide unsupported fallback features through capability state, not fallback-specific branches.
   - Alternative considered: hard-code common VLC capability differences in UI. Rejected because UI must not depend on VLC directly.

5. **Publish fallback events through `CacheInvalidationBus`.**
   - Decision: fallback registration, deregistration, capability reevaluation, selection, and state transitions publish bus events.
   - Rationale: existing Phase 5 slices use event-driven invalidation instead of cross-module callbacks.
   - Alternative considered: direct callbacks into playback UI or diagnostics. Rejected because those layers are outside this contract slice.

## Risks / Trade-offs

- **Risk: fallback appears to promise concrete VLC support.** → Mitigation: specs, code, and checker rules explicitly forbid VLC packages/native plugins and keep fallback optional.
- **Risk: hidden capabilities become ambiguous.** → Mitigation: typed capability reevaluation and selection outcomes carry explicit reason strings per hidden capability.
- **Risk: fallback selection overlaps with primary adapter failure handling.** → Mitigation: MPV/primary adapter contracts continue to normalize failures; fallback strategy consumes those failures but does not own primary adapter lifecycle.
- **Risk: storage creates premature migration obligations.** → Mitigation: store only small declarative records and state metadata, not concrete adapter resources.

## Migration Plan

1. Add `vlc-fallback-adapter-contract` specs and deltas for affected specs.
2. Extend Dart contracts with fallback storage records/store, typed outcomes/failures, deterministic strategy, capability hiding, and invalidation events.
3. Update public exports, runtime checks, focused tests, Phase 5 docs, and advanced playback checker rules.
4. Validate with OpenSpec, analyzer, focused Flutter tests, runtime checks, and Phase 5 checker scripts.

Rollback is straightforward because this change introduces contract/value/state scaffolding only; no native fallback adapter or external dependency is introduced.

## Open Questions

- None blocking for the contract slice. Concrete VLC package choice, platform adapter behavior, diagnostics display, and fallback UX are intentionally deferred.
