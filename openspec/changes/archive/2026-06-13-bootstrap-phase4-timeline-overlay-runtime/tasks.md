## 1. Runtime Shape and Red Tests

- [x] 1.1 Add focused runtime tests for composing timeline snapshots from playback state, virtual stream descriptors, buffered ranges, BT piece segments, scheduler priority windows, markers, heat values, and persisted layer profiles.
- [x] 1.2 Add tests for profile selection, active profile restoration, layer visibility changes, layer ordering, hidden layers, and latest snapshot metadata replay.
- [x] 1.3 Add tests for typed failures: missing duration, invalid stream length, duplicate layer identifiers, missing profile, unavailable stream input, rejected composition, invalid layer configuration, and disposed runtime state.
- [x] 1.4 Add tests proving invalidation events are observed only after profile, layer, snapshot, or rejection state is storage-visible.

## 2. Runtime and Projection Implementation

- [x] 2.1 Add `TimelineOverlayRuntime` and `TimelineOverlayBootstrap` around the existing deterministic timeline overlay composer and timeline overlay store.
- [x] 2.2 Implement lifecycle-safe runtime action results for composition, profile selection, layer configuration, snapshot lookup, rejected composition, dependency-unavailable state, and disposed runtime state.
- [x] 2.3 Implement immutable runtime projections for active profile, ordered layers, latest snapshot metadata, latest composition rejection, and restart-visible overlay state.
- [x] 2.4 Compose timeline snapshots from read-only playback, virtual stream, buffered range, BT piece segment, scheduler priority, marker, heat, and layer-profile inputs.
- [x] 2.5 Persist overlay profiles, active profile per stream, ordered layer preferences, visibility, and latest snapshot metadata before exposing runtime snapshots.
- [x] 2.6 Keep timeline overlay runtime read-only over BT task, virtual stream, scheduler, playback, and byte-serving domains.

## 3. Storage and Cache Contracts

- [x] 3.1 Extend timeline overlay storage contracts only if needed for runtime profile, active profile, ordered layer, snapshot metadata, or rejection replay.
- [x] 3.2 Ensure profile selection and layer configuration updates are persisted atomically before snapshots or invalidations expose the change.
- [x] 3.3 Publish timeline overlay invalidation events after successful snapshot refresh, profile selection, layer configuration, and rejected composition.
- [x] 3.4 Keep invalidation payloads identifier/projection-only with no widget, rendering, playback, or transport instructions.

## 4. Public Surface and Boundary Preservation

- [x] 4.1 Export the Step 21 runtime/bootstrap surface from `lib/elaina.dart` after focused tests pass.
- [x] 4.2 Preserve existing `TimelineOverlayComposer` and `TimelineOverlayStore` contracts while adding runtime/bootstrap projections.
- [x] 4.3 Ensure piece-priority scheduler inputs are consumed as read-only projections and no scheduler plan generation or application is invoked by timeline overlay runtime.
- [x] 4.4 Ensure virtual stream inputs are consumed as read-only descriptors/buffered ranges and no stream lifecycle or byte-range serving operation is invoked by timeline overlay runtime.

## 5. Validation Tooling

- [x] 5.1 Add `tools/timeline_overlay_runtime_check.dart` covering runtime bootstrap, snapshot composition, profile/layer persistence, typed failures, invalidation ordering, restart projection, and disposed behavior.
- [x] 5.2 Add `tools/check_timeline_overlay_runtime.ps1` with required file checks, Dart smoke check, barrel export checks, required-term checks, and forbidden boundary-term checks.
- [x] 5.3 Run focused timeline contract and runtime tests.
- [x] 5.4 Run the Dart timeline overlay runtime smoke checker.
- [x] 5.5 Run the PowerShell timeline overlay runtime boundary checker.
- [x] 5.6 Run `dart analyze`.
- [x] 5.7 Run `openspec validate "bootstrap-phase4-timeline-overlay-runtime" --strict`.
- [x] 5.8 Run `openspec validate --all`.

## 6. Scope Guard

- [x] 6.1 Inspect the runtime, tests, and checker surfaces for Flutter UI, rendering, drawing, gesture, hover, tooltip, widget, or visual-design leakage.
- [x] 6.2 Inspect the runtime, tests, and checker surfaces for playback control, seek execution, pause/resume, MPV/VLC/media-kit, platform channel, BT mutation, scheduler mutation, libtorrent, FFI, socket, file IO, HTTP/range server, or pipe server leakage.
- [x] 6.3 Inspect the runtime, tests, and checker surfaces for unrelated later-phase leakage: RSS auto-download, online-rule runtime, diagnostics center, Anime4K, AV sync, captions, storage migrations, or Phase 5 features.
