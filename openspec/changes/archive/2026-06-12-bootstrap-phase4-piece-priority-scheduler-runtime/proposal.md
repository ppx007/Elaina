## Why

Phase 4 Step 18 and Step 19 now provide replayable BT task state and virtual media stream projections, but playback-aware downloading still needs a Step 20 scheduler runtime boundary that can turn those persisted inputs into deterministic priority plans. Existing scheduler contracts and deterministic planning code are present, so this change formalizes and hardens the PiecePriorityScheduler runtime/bootstrap slice without entering timeline overlay, UI, concrete torrent-engine, or native playback work.

## What Changes

- Add a Phase 4 Step 20 runtime/bootstrap capability for piece priority scheduling over BT task metadata, virtual stream descriptors, buffered ranges, playback windows, seek targets, and strategy profiles.
- Harden scheduler planning outcomes for profile selection, file-piece map derivation, first/tail piece priorities, playback-window priorities, seek-target priorities, buffered-piece avoidance, and typed failure cases.
- Define plan application recording as an adapter-neutral boundary with accepted, rejected, and unavailable outcomes, not direct engine mutation.
- Extend storage and cache contracts for restart-safe scheduler projections, active profile state, generated plans, plan rules, latest application events, and post-mutation invalidation ordering.
- Preserve downstream handoff for Step 21 timeline overlays as read-only priority projections while keeping timeline composition out of this change.
- Add focused tests, smoke checker, and boundary checker that prove Step 20 remains isolated from concrete IO, libtorrent/FFI, player/native bindings, UI, RSS automation, diagnostics, network, and storage migration work.

## Capabilities

### New Capabilities
- `phase4-piece-priority-scheduler-runtime`: Phase 4 Step 20 runtime/bootstrap acceptance for deterministic piece priority planning, replayable scheduler projections, and adapter-neutral application recording.

### Modified Capabilities
- `piece-priority-scheduler`: Clarify runtime/bootstrap behavior, scheduler projections, lifecycle-safe outcomes, and Step 20 scope boundaries.
- `piece-priority-scheduler-contract`: Define contract-safe runtime inputs, typed failures, persisted plan/application state, and downstream timeline-safe projections.
- `bt-task-core`: Preserve scheduler input state from BT metadata, file offsets, piece length, lifecycle, and selected file records.
- `bt-task-core-contract`: Require scheduler handoff inputs to stay engine-neutral and replayable.
- `virtual-media-stream`: Provide scheduler-safe stream descriptors, lifecycle state, and buffered range projections without scheduler-owned stream mutation.
- `virtual-media-stream-contract`: Clarify that scheduler consumers read virtual stream snapshots and buffered ranges without owning byte delivery or stream lifecycle.
- `local-storage-foundation`: Extend storage expectations for scheduler runtime state, restart reconstruction, and storage boundary enforcement.
- `cache-invalidation-bus`: Extend invalidation semantics for scheduler profile changes, plan generation, plan application, plan rejection, and post-mutation read ordering.
- `repository-baseline`: Add Step 20 isolation and boundary validation expectations.

## Impact

- Likely implementation anchor: `lib/src/streaming/piece_priority_scheduler.dart`.
- Likely storage anchor: `lib/src/foundation/storage/piece_priority_scheduler_storage_contracts.dart`.
- Likely validation additions: focused scheduler runtime tests plus `tools/piece_priority_scheduler_runtime_check.dart` and `tools/check_piece_priority_scheduler_runtime.ps1`.
- Step 20 consumes Step 18 task state and Step 19 virtual stream state, then feeds later Step 21 timeline overlays as read-only projection data.
- No concrete torrent engine, libtorrent, FFI, socket, HTTP/range server, filesystem byte serving, native player, MPV/VLC/media-kit, Flutter UI, RSS automation, online-rule, diagnostics, network, or storage migration implementation is introduced.
