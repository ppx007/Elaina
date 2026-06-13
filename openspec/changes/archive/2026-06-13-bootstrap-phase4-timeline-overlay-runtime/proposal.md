## Why

Phase 4 Step 18-20 now establish replayable BT task, virtual stream, and piece-priority scheduler projections, but playback still lacks the Step 21 boundary that turns those projections into deterministic timeline overlay snapshots. This change adds the runtime/bootstrap acceptance layer for presentation-facing timeline overlays without entering UI rendering or playback control.

## What Changes

- Add a Step 21 `TimelineOverlayRuntime` / `TimelineOverlayBootstrap` capability around the existing deterministic timeline overlay composer.
- Compose immutable timeline overlay snapshots from playback position/duration, virtual stream descriptors, buffered ranges, BT piece segments, scheduler priority windows, markers, heat values, and persisted layer preferences.
- Persist overlay-safe presentation state: profiles, active profile per stream, ordered layer visibility/configuration, and latest snapshot metadata.
- Publish cache invalidation only after storage-visible profile/layer changes, successful snapshot refreshes, and rejected compositions.
- Add typed runtime outcomes for snapshot composition, profile selection, layer configuration, missing stream/duration inputs, invalid layer configuration, missing profile, dependency-unavailable state, and disposed runtime state.
- Keep TimelineOverlay read-only over BT, virtual stream, scheduler, and playback inputs.
- Add focused runtime tests, a Dart smoke checker, and a PowerShell boundary checker for Step 21 scope.
- Exclude Flutter widgets, timeline drawing, gestures, playback control, BT mutation, scheduler plan generation/application, concrete range serving, native player integration, diagnostics behavior, and Phase 5 features.

## Capabilities

### New Capabilities
- `phase4-timeline-overlay-runtime`: Phase 4 Step 21 runtime/bootstrap acceptance for deterministic timeline overlay composition, persisted overlay-safe presentation state, immutable snapshots, and cache invalidation.

### Modified Capabilities
- `timeline-overlay`: Add runtime/bootstrap behavior for progress, buffered ranges, BT blocks, priority windows, markers, heat values, layer visibility, and layer ordering.
- `timeline-overlay-contract`: Tighten immutable snapshot, independent layer, derived projection, storage-safe state, invalidation, and Step 21 boundary requirements.
- `virtual-media-stream`: Expose overlay-safe stream descriptors and buffered range snapshots as read-only timeline inputs.
- `virtual-media-stream-contract`: Clarify that overlay consumers cannot serve bytes, close streams, or mutate stream lifecycle.
- `piece-priority-scheduler`: Expose timeline-safe priority window and priority rule summaries from generated plans.
- `piece-priority-scheduler-contract`: Require scheduler-derived overlay data to remain read-only and replayable.
- `local-storage-foundation`: Add Step 21 timeline overlay profile, layer preference, active profile, snapshot metadata, and restart reconstruction persistence requirements.
- `cache-invalidation-bus`: Add Step 21 timeline overlay runtime invalidation ordering and payload-only event requirements.
- `repository-baseline`: Add Step 21 isolation and boundary validation expectations.

## Impact

- Likely implementation anchors: `lib/src/streaming/timeline_overlay.dart`, new `lib/src/streaming/timeline_overlay_runtime.dart`, `lib/src/foundation/storage/timeline_overlay_storage_contracts.dart`, and `lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart`.
- Public export impact: `lib/celesteria.dart` should export the runtime/bootstrap surface after tests pass.
- Test impact: add `test/streaming/timeline_overlay_runtime_test.dart` while preserving existing `test/streaming/timeline_overlay_contract_test.dart`.
- Tooling impact: add `tools/timeline_overlay_runtime_check.dart` and `tools/check_timeline_overlay_runtime.ps1`.
- Downstream impact: future UI/timeline rendering work may consume runtime snapshots, but this change does not implement widgets, gestures, drawing, or playback control.
