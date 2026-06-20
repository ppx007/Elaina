## Context

Phase 0 now exposes `FoundationBootstrap`, `FoundationRuntime`, deterministic storage, ProviderGateway, CacheInvalidationBus, and layer-boundary validation as a composed runtime. Phase 1 contracts already exist for MPV adapter boundary, playback capability matrix, playback controller, playback state, track management, and playback page foundation, but they are not yet assembled into one lifecycle-managed runtime entry point.

This change follows the architecture plan order: Step 1-4 foundation first, then Step 5-8 player core. It deliberately mirrors the Phase 0 bootstrap pattern while keeping actual native playback bindings, app shell, provider data, BT streaming, and advanced playback out of scope.

## Goals / Non-Goals

**Goals:**
- Provide a `PlayerCoreBootstrap` entry point for Phase 1 Step 5-8 surfaces.
- Provide a `PlayerCoreRuntime` that composes adapter facade, controller, capability matrix, track runtime, clock, and playback state observation.
- Provide deterministic MPV binding/runtime scaffolding so tests can exercise supported and unsupported player-core behavior without native MPV/libmpv/media-kit.
- Prove Phase 1 builds on Phase 0 foundation without making Foundation, UI, Provider, Storage internals, Streaming, or Network own player lifecycle decisions.
- Add checker and test coverage for player-core boundary terms, lifecycle cleanup, capability gating, track switching, and state observation.

**Non-Goals:**
- No real MPV, libmpv, media-kit, ExoPlayer, AVPlayer, VLC, or platform channel integration.
- No Flutter app shell, `main.dart`, navigation, or actual video surface rendering.
- No provider metadata, Bangumi, Dandanplay, subtitle provider, RSS, BT streaming, network policy, diagnostics UI, or advanced enhancement integration.
- No production storage or network adapter changes.

## Decisions

### Decision 1: Mirror Phase 0 with `PlayerCoreBootstrap` and `PlayerCoreRuntime`

The Phase 1 runtime should use the same public pattern as Phase 0: a bootstrap entry point with default deterministic construction and a runtime object that owns lifecycle-managed dependencies. This makes Step 5-8 composition explicit and gives later app-shell work a stable dependency rather than forcing it to manually assemble adapter, controller, tracks, and state objects.

Alternative considered: extend `FoundationBootstrap` to include player-core surfaces directly. Rejected because it would blur Phase 0 and Phase 1 ownership and make Foundation aware of Playback implementation details.

### Decision 2: Keep deterministic MPV binding behind Playback-layer contracts

The default runtime should use deterministic scaffolding that can simulate supported and unsupported adapter states without native bindings. This preserves existing unsupported facade behavior while enabling tests for a bound adapter path.

Alternative considered: introduce media-kit/libmpv now. Rejected because native playback is a later implementation concern and would create platform and dependency risk before runtime composition is validated.

### Decision 3: Derive capability matrix from the active adapter

`PlayerCoreRuntime` should expose a capability matrix that is computed from the active adapter/binding declaration rather than duplicating UI or Domain assumptions. Controller surface decisions and track operations must read the same matrix.

Alternative considered: hard-code a Phase 1 default matrix. Rejected because it would create drift between adapter reality and UI/controller behavior.

### Decision 4: Runtime owns lifecycle cleanup

`PlayerCoreRuntime.dispose()` should close/dispose the active adapter binding and state observation resources. Public access after disposal should be rejected deterministically, matching the Phase 0 runtime lifecycle pattern.

Alternative considered: leave adapter lifecycle to callers. Rejected because it makes early app-shell wiring error-prone and hides resource ownership.

### Decision 5: Playback page foundation consumes runtime surfaces indirectly

The playback page foundation should consume Domain/UI surface descriptors driven by `PlayerCoreRuntime` state and capabilities. UI code must not import concrete MPV binding, track implementation, or adapter internals.

Alternative considered: let playback UI resolve adapters directly for faster wiring. Rejected because the global architecture explicitly forbids UI direct dependency on playback engine implementations.

## Risks / Trade-offs

- Deterministic binding behavior could be mistaken for native playback support → Keep real native binding out of the default constructor and make unsupported/supported capability declarations explicit.
- Runtime composition may duplicate checks already present in `player_core_runtime_check.dart` → Extract or reuse deterministic concepts in focused tests while keeping the runtime checker as a broad smoke gate.
- Adding `PlayerCoreRuntime` before app shell may seem non-runnable → This is intentional; it provides the contract-safe runtime surface the app shell can own later.
- Too much UI scope could leak into Phase 1 → Limit playback page work to descriptor/runtime consumption requirements, not widgets or navigation.

## Migration Plan

1. Add player-core runtime/bootstrap files under `lib/src/domain/playback/` and deterministic binding scaffolding under `lib/src/playback/`.
2. Export the new contract-safe player-core runtime surfaces through `lib/elaina.dart`.
3. Add focused tests under `test/playback/`.
4. Extend or add checker scripts for Phase 1 runtime boundary validation.
5. Run OpenSpec validation, analyzer, focused tests, player-core runtime check, and boundary checker scripts.

Rollback is straightforward because the change is additive: remove the new runtime/bootstrap files, tests, exports, checker updates, and spec deltas.

## Open Questions

- Whether the deterministic MPV binding should be a public test scaffold or kept as an internal runtime helper.
- Whether `PlayerCoreRuntime` should depend on `FoundationRuntime` directly or accept a smaller read-only descriptor proving Phase 0 availability.
- Whether app-shell bootstrap should be the immediate next change after this runtime or postponed until a native adapter binding exists.
