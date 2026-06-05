## Why

Step 18 now provides durable BT task orchestration, but Step 19 is still only a bootstrap-level virtual stream interface. Playback cannot safely consume BT-backed media until byte-range reads, buffered range state, and stream lifecycle handoff are represented through engine-neutral contracts.

## What Changes

- Add durable VirtualMediaStream contracts for stream descriptors, byte range requests, buffered range snapshots, lifecycle state, and latest range events.
- Add a deterministic virtual media stream registry that creates streams from persisted BT task metadata and selected files without exposing torrent engine objects to Playback or UI.
- Add range orchestration outcomes and failure types for metadata unavailable, file unavailable, range unavailable, timeout, cancellation, and task failure.
- Persist stream descriptors and buffered ranges through Storage-layer contracts so stream state can be reconstructed after restart.
- Publish cache invalidation events for virtual stream creation, buffered range updates, range failures, and stream closure.
- Update Phase 4 guardrails and runtime validation to keep this slice free of concrete HTTP servers, sockets, FFI, libtorrent, piece-priority scheduling, timeline overlay rendering, and RSS automation.

## Capabilities

### New Capabilities

- `virtual-media-stream-contract`: Durable Step 19 contract for task-backed virtual media stream creation, range orchestration, buffered range persistence, and invalidation events.

### Modified Capabilities

- `virtual-media-stream`: Refine the bootstrap virtual stream specification into a durable range-read and buffered-range contract.
- `bt-task-core-contract`: Define the handoff from persisted BT task metadata and selected files into virtual stream creation.
- `local-storage-foundation`: Add storage responsibilities for virtual stream descriptors, buffered range snapshots, and latest stream range events.
- `cache-invalidation-bus`: Add virtual stream invalidation events for stream lifecycle and buffered range changes.
- `playback-source-handoff-contract`: Clarify that playback receives a virtual stream playback source without importing BT task or engine internals.

## Impact

- Affected code: `lib/src/streaming/virtual_media_stream.dart`, Storage contracts, cache invalidation bus, playback source handoff contracts, Phase 4 checker scripts, runtime validation, and deterministic tests.
- Affected specs: `virtual-media-stream-contract`, `virtual-media-stream`, `bt-task-core-contract`, `local-storage-foundation`, `cache-invalidation-bus`, and `playback-source-handoff-contract`.
- No concrete download engine, HTTP range server, socket, FFI, libtorrent binding, piece-priority scheduler, timeline overlay, UI task screen, or RSS auto-download behavior is introduced.
