## Why

Step 18 now provides an engine-neutral BT task runtime that can persist task metadata and selected file state, but playback still needs a Step 19 runtime boundary that turns those selected files into replayable virtual media streams. This change freezes the VirtualMediaStream runtime/bootstrap slice before downstream piece-priority scheduling and timeline overlay work consume its range and buffer projections.

## What Changes

- Introduce a Phase 4 virtual media stream runtime/bootstrap capability that composes existing virtual stream, BT task storage, cache invalidation, and playback handoff contracts.
- Define deterministic stream creation, lookup, lifecycle projection, buffered range recording, range failure handling, and restart-safe snapshots for selected BT files.
- Clarify how virtual stream descriptors become playback-safe source handoff inputs without exposing concrete byte servers, torrent engines, FFI, native player bindings, or UI dependencies.
- Extend storage and cache invalidation contracts for virtual stream lifecycle/range state and post-mutation invalidation ordering.
- Keep Step 20 piece-priority scheduling and Step 21 timeline overlay as downstream consumers only; this change does not implement scheduler runtime, timeline composition, concrete IO, range servers, or native playback adapters.

## Capabilities

### New Capabilities
- `phase4-virtual-media-stream-runtime`: Runtime/bootstrap contract for selected BT files to become deterministic virtual media stream projections, range availability records, and playback handoff inputs.

### Modified Capabilities
- `virtual-media-stream`: Add runtime/bootstrap requirements for stream descriptors, lifecycle projections, buffered ranges, restart replay, and typed failures.
- `virtual-media-stream-contract`: Clarify that byte delivery remains adapter-bound and that runtime behavior stops at range availability and buffered-state recording.
- `bt-task-core`: Add handoff requirements from persisted task metadata and selected file records into virtual stream creation.
- `bt-task-core-contract`: Require selected-file metadata to be sufficient for virtual stream bootstrap without concrete engine access.
- `local-storage-foundation`: Add atomic persistence expectations for virtual stream lifecycle, buffered ranges, failures, and restart reconstruction.
- `cache-invalidation-bus`: Add correlated invalidations for virtual stream creation, range buffering, range failures, and close/failure lifecycle changes.
- `playback-source-handoff-contract`: Clarify playback source preparation for virtual stream descriptors while rejecting direct BT engine/task internals.
- `repository-baseline`: Add Step 19 isolation and boundary validation requirements that forbid scheduler, timeline, concrete IO, network, UI, diagnostics, and native player leakage.

## Impact

- Affected code will likely include `lib/src/streaming/virtual_media_stream.dart`, a new virtual stream runtime/bootstrap file, BT task storage contract usage, cache invalidation events, public exports, focused runtime tests, and a validation checker.
- Existing Step 18 BT task runtime remains the upstream source for task metadata and selected files.
- Later Step 20 and Step 21 work may consume virtual stream descriptors and buffered range snapshots, but they are not implemented by this change.
