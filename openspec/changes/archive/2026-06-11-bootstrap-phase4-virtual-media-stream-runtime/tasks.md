## 1. Runtime Shape and Red Tests

- [x] 1.1 Streaming layer: Add failing tests for virtual stream runtime creation from selected BT task files - expect selected files to create deterministic descriptors
- [x] 1.2 Streaming layer: Add failing tests for missing task, missing metadata, skipped file, closed stream, failed stream, and out-of-range failures - expect typed outcomes without concrete IO
- [x] 1.3 Streaming layer: Add failing tests for restart-safe stream snapshots and immutable buffered range projections - expect replay from storage records
- [x] 1.4 Playback layer: Add failing tests for virtual stream playback handoff inputs - expect playback-safe source values and rejected BT internals

## 2. Runtime and Projection Implementation

- [x] 2.1 Streaming layer: Implement `VirtualMediaStreamRuntime` or equivalent bootstrap surface - expect composition of registry/store/cache/clock dependencies
- [x] 2.2 Streaming layer: Implement stream create, lookup, list, close, fail, ensure-range, and buffered-range projection actions - expect typed action outcomes
- [x] 2.3 Streaming layer: Implement restart projection for active, closed, failed, incomplete, missing-task, and range-failed streams - expect deterministic snapshots
- [x] 2.4 Streaming layer: Keep range delivery adapter-neutral - expect no concrete byte serving, socket, file, FFI, torrent engine, or native player dependency

## 3. Storage and Cache Contracts

- [x] 3.1 Storage layer: Extend or reuse virtual stream storage records for lifecycle, buffered ranges, latest event/failure, and updated timestamps - expect replayable state
- [x] 3.2 Storage layer: Preserve atomic post-mutation visibility for create, range-buffered, range-failed, close, and fail transitions - expect reads observe state before invalidations matter
- [x] 3.3 Gateway/foundation layer: Add or reuse virtual stream cache invalidation payloads for created, range buffered, range failed, closed, and failed mutations - expect correlated stream/task/file metadata
- [x] 3.4 Gateway/foundation layer: Verify cache invalidation remains payload-only - expect no UI refresh, engine polling, priority application, timeline composition, or playback control

## 4. Playback Handoff and Public Surface

- [x] 4.1 Playback layer: Extend playback source handoff support for virtual stream runtime projections or descriptors - expect existing playback source model reuse
- [x] 4.2 Playback layer: Reject direct BT task, engine, piece map, scheduler, timeline, socket, file handle, or native player values - expect explicit unsupported outcomes
- [x] 4.3 Public API: Export the Step 19 runtime/bootstrap surface from `lib/elaina.dart` only after focused tests pass - expect stable public contract access
- [x] 4.4 Repository baseline: Confirm Step 19 remains optional and does not require Step 20 scheduler, Step 21 timeline, Phase 6, diagnostics, UI, network, storage migration, or native player work

## 5. Validation Tooling

- [x] 5.1 Tools: Add a Dart smoke checker for virtual media stream runtime bootstrap - expect creation, range recording, failure, close, restart, cache, and handoff assertions
- [x] 5.2 Tools: Add a PowerShell boundary checker for Step 19 runtime files - expect forbidden terms to fail validation
- [x] 5.3 Tests: Run focused virtual media stream runtime and playback handoff tests - expect all focused tests pass
- [x] 5.4 Analysis: Run `dart analyze` - expect no analyzer issues from Step 19 changes
- [x] 5.5 OpenSpec: Run `openspec validate "bootstrap-phase4-virtual-media-stream-runtime" --strict` - expect strict validation pass
- [x] 5.6 OpenSpec: Run `openspec validate --all` - expect all specs pass

## 6. Scope Guard

- [x] 6.1 Scope guard: Inspect changed files for Step 20 and Step 21 leakage - expect no scheduler runtime, timeline runtime, concrete range server, or UI implementation
- [x] 6.2 Scope guard: Inspect changed files for concrete IO/native leakage - expect no `dart:io`, HTTP server, socket, `RandomAccessFile`, libtorrent, FFI, MPV/VLC, media-kit, platform channel, or native player dependency
- [x] 6.3 Scope guard: Inspect changed files for unrelated later phases - expect no RSS auto-download, online-rule runtime, diagnostics center, network policy, or storage migration implementation
