## 1. Runtime Shape and Red Tests

- [x] 1.1 Add focused scheduler runtime tests for plan generation from persisted BT task metadata, selected file records, virtual stream descriptors, buffered ranges, playback windows, seek targets, and strategy profiles.
- [x] 1.2 Add tests for typed planning failures covering missing metadata, missing file-piece map, unavailable stream, closed or failed stream, unsupported profile, range out of bounds, no schedulable pieces, and disposed runtime state.
- [x] 1.3 Add tests for adapter-neutral application recording covering accepted, rejected, unavailable applier, missing plan, stale plan, and replayable latest application outcomes.
- [x] 1.4 Add tests for immutable scheduler snapshots and restart projections covering active profile, latest plan, ordered rules, latest application event, rejected plan, and unavailable input state.

## 2. Runtime and Projection Implementation

- [x] 2.1 Add or harden a `PiecePrioritySchedulerRuntime` and `PiecePrioritySchedulerBootstrap` surface around existing scheduler contracts.
- [x] 2.2 Implement lifecycle-safe runtime action results for plan generation, profile selection, plan lookup, plan application recording, projection reads, unavailable dependencies, and disposed state.
- [x] 2.3 Implement runtime projections for active profile, generated plan summaries, ordered priority rules, latest application outcomes, latest planning failures, and restart visibility.
- [x] 2.4 Ensure planning derives file-piece maps from persisted BT task metadata and selected file records without probing concrete engine sessions.
- [x] 2.5 Ensure planning consumes virtual stream descriptors and buffered ranges as read-only input and avoids fully buffered pieces where possible.
- [x] 2.6 Ensure plan application remains adapter-neutral and records accepted, rejected, or unavailable outcomes without direct engine mutation.

## 3. Storage and Cache Contracts

- [x] 3.1 Extend scheduler storage contracts only if required for replayable runtime snapshots, stale-plan detection, latest failure state, or restart-safe projection reads.
- [x] 3.2 Persist active profile, generated plans, ordered plan rules, and application outcomes before exposing updated scheduler snapshots.
- [x] 3.3 Publish scheduler invalidation payloads after storage-visible profile selection, plan generation, plan application, plan rejection, and unavailable application outcomes.
- [x] 3.4 Keep cache invalidation payload-only: no UI refresh, stream mutation, priority application, torrent polling, timeline composition, diagnostics, or native playback side effects.

## 4. Public Surface and Downstream Handoff

- [x] 4.1 Export the Step 20 runtime/bootstrap surface from `lib/elaina.dart` only after focused tests pass.
- [x] 4.2 Provide timeline-safe priority projection data for later Step 21 consumers without implementing timeline overlay composition or rendering.
- [x] 4.3 Preserve playback and virtual stream boundaries so scheduler runtime does not close streams, serve bytes, mutate buffered ranges, or control player adapters.
- [x] 4.4 Confirm BT task core remains the source of scheduler metadata and selected-file state, not concrete engine objects.

## 5. Validation Tooling

- [x] 5.1 Add `tools/piece_priority_scheduler_runtime_check.dart` covering creation/bootstrap, plan generation, buffered-piece avoidance, typed failure, application recording, restart projection, and invalidation ordering.
- [x] 5.2 Add `tools/check_piece_priority_scheduler_runtime.ps1` chaining required foundation checks, Dart smoke check, required-term checks, barrel export checks, and forbidden boundary-term checks.
- [x] 5.3 Run focused scheduler tests, including existing `test/streaming/piece_priority_scheduler_contract_test.dart` and any new runtime tests.
- [x] 5.4 Run `dart run tools/piece_priority_scheduler_runtime_check.dart`.
- [x] 5.5 Run `powershell -ExecutionPolicy Bypass -File "tools\check_piece_priority_scheduler_runtime.ps1"`.
- [x] 5.6 Run `dart analyze`.
- [x] 5.7 Run `openspec validate "bootstrap-phase4-piece-priority-scheduler-runtime" --strict`.
- [x] 5.8 Run `openspec validate --all`.

## 6. Scope Guard

- [x] 6.1 Inspect Step 20 runtime files and tests for forbidden Step 21 timeline overlay runtime, overlay composition, heat maps, markers, timeline UI, or layer rendering behavior.
- [x] 6.2 Inspect Step 20 runtime files and tests for forbidden concrete IO/native dependencies: `dart:io`, `HttpServer`, `Socket`, `RandomAccessFile`, pipe/range server implementation, `ffi`, `libtorrent`, `mpv`, `vlc`, `media-kit`, platform channels, or native player bindings.
- [x] 6.3 Inspect Step 20 runtime files and tests for unrelated later-phase leakage: Flutter UI, RSS auto-download runtime, online-rule runtime, diagnostics center, network implementation, storage migrations, Phase 5 video enhancement, AV sync, advanced captions, or fallback adapter behavior.
