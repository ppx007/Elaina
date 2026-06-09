## Context

The architecture plan places Phase 2 / Step 12 immediately after the Dandanplay provider runtime. Current code already exposes basic danmaku data contracts in the Playback layer: `DanmakuComment`, `DanmakuMode`, `DanmakuFilter`, `DanmakuDensityPolicy`, `DanmakuRenderLane`, `DanmakuRenderFrame`, and `BasicDanmakuRenderer`. Dandanplay now provides deterministic comment retrieval/posting through ProviderGateway, but the renderer side is only an interface and there is no runtime snapshot, Domain projection, playback state field, playback page overlay descriptor, focused test, or checker script.

This change is the bridge between provider-sourced danmaku comments and player-clock-driven overlay frames. It must stop before Flutter widget painting, Canvas/CustomPainter, native renderer integration, Matrix4/special danmaku, masking, diagnostics, and A/V degradation workflows.

## Goals / Non-Goals

**Goals:**

- Provide deterministic basic danmaku runtime behavior for scrolling, top, and bottom comments.
- Use `PlayerClockSnapshot` as the single timing source for frame eligibility and ordering.
- Implement filter and density semantics already declared by `DanmakuFilter` and `DanmakuDensityPolicy`.
- Add lifecycle-safe runtime state, immutable snapshots, and observer-friendly frame resolution similar to the basic subtitle runtime pattern.
- Add a narrow Dandanplay-to-Danmaku normalization bridge without making Playback import Provider runtime implementations.
- Extend Domain playback state and playback page surface descriptors with framework-neutral danmaku overlay values.
- Add focused tests and validation scripts that prove Step 12 remains basic, deterministic, and isolated from advanced captions, providers, network, storage, concrete UI, and native player code.

**Non-Goals:**

- No Flutter widget, CustomPainter, Canvas, DOM, or native renderer implementation.
- No Matrix4 danmaku, reverse/L2R comments, precise positioning, masking, superchat bubbles, ASS/BAS special effects, or advanced caption integration.
- No Dandanplay HTTP transport, ProviderGateway changes, account/session state, comment fetching scheduler, cache persistence, or storage migration.
- No direct playback adapter, MPV/VLC, libmpv, media-kit, platform channel, RSS, BT, online-rule, network policy, or diagnostics behavior.

## Decisions

1. **Use a pull-based runtime API for Step 12.**
   - Rationale: the subtitle runtime already resolves clock-relative overlays on demand, and Step 12 only needs deterministic frame snapshots rather than a real animation loop.
   - Alternative considered: subscribe directly to `PlayerClock.snapshots` and emit a frame stream. Rejected for this slice because smooth frame ticking belongs to future UI/native renderer integration.

2. **Keep rendering contracts in Playback and projection contracts in Domain/UI.**
   - Rationale: Playback owns player-clock overlay semantics, Domain owns framework-neutral playback state, and UI owns page descriptors.
   - Alternative considered: put all danmaku overlay descriptors in UI. Rejected because Domain playback state needs a provider-neutral snapshot that can be observed before UI exists.

3. **Normalize Dandanplay comments through a bridge instead of coupling Playback to Provider.**
   - Rationale: Dandanplay and Playback use equivalent modes but different value types. A bridge can map provider comment data to `DanmakuComment` without importing provider runtime into playback rendering.
   - Alternative considered: change `DandanplayComment` to extend or reuse `DanmakuComment`. Rejected because Provider-layer contracts should not depend on Playback-layer render value objects.

4. **Apply density after filtering and before lane grouping.**
   - Rationale: hidden/blocked comments should not consume density budget, and deterministic tests can assert exact lane contents.
   - Alternative considered: lane-first then filter. Rejected because it can leave holes and make density behavior less predictable.

5. **Do not implement collision physics in Step 12.**
   - Rationale: existing contract only exposes lanes grouped by mode; no viewport size, text metrics, item velocity, or x/y positions exist yet.
   - Alternative considered: add draw-item positions and scroll speeds now. Rejected because concrete geometry belongs to a later renderer adapter/widget slice.

## Risks / Trade-offs

- **[Risk] Basic danmaku expands into advanced rendering.** → Mitigation: forbid Matrix4, special-position, reverse, masking, and native renderer terms in Step 12 checker scripts.
- **[Risk] Playback imports Dandanplay provider implementations.** → Mitigation: keep conversion helpers in Domain/ACG bridge code and validate Playback danmaku files for provider/gateway imports.
- **[Risk] Playback page surface specs previously excluded danmaku.** → Mitigation: update the exclusion requirement to allow basic framework-neutral danmaku overlay descriptors while still excluding concrete rendering and advanced systems.
- **[Risk] Pull-based frame snapshots do not animate smoothly.** → Mitigation: explicitly scope this runtime to deterministic frame resolution; future UI/native renderer changes can add ticker streams without changing the basic state contract.
- **[Risk] Density semantics become ambiguous.** → Mitigation: define deterministic ordering, filtering, and max-comments-per-window behavior in specs and focused tests.

## Migration Plan

1. Extend basic danmaku Playback contracts with deterministic runtime, renderer implementation, runtime snapshot, lifecycle, and immutable frame data.
2. Add Domain state projection and Dandanplay comment normalization helpers.
3. Extend playback state and playback page surface descriptors with framework-neutral danmaku overlay data.
4. Export only safe contracts and runtime/bootstrap surfaces through `lib/celesteria.dart`.
5. Add focused tests, smoke check, and boundary checker script.
6. Run `openspec validate "bootstrap-phase2-basic-danmaku-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused danmaku tests, checker scripts, and existing Dandanplay/subtitle/player runtime smoke checks.

Rollback before archive is file deletion plus removing this change directory. No persisted data or storage migration is introduced.

## Open Questions

- Smooth animation ticks, draw-item x/y geometry, viewport sizing, font metrics, and lane collision physics should be designed in a later concrete renderer/UI adapter change.
- Whether danmaku overlay controls should become first-class playback page controls should wait until actual UI panels are implemented.
