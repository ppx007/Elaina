## Why

Steps 18 and 19 now provide durable BT task state and virtual stream range state, but Step 20 is still only a bootstrap-level priority-planning interface. Playback-aware BT streaming cannot remain stable across startup, seek, and tail-piece scenarios until piece priority plans, strategy profiles, and plan application outcomes are represented through deterministic, engine-neutral contracts.

## What Changes

- Add durable PiecePriorityScheduler contracts for playback windows, seek targets, first/tail piece emphasis, strategy profiles, plan outcomes, and plan application records.
- Add deterministic priority planning that derives file-piece windows from persisted BT task metadata and virtual stream descriptors without querying concrete download engines.
- Persist scheduler profiles, generated priority plans, and latest plan application events through Storage-layer contracts.
- Publish cache invalidation events when priority plans are generated, applied, rejected, or when the active scheduler profile changes.
- Update Phase 4 runtime validation and boundary checkers so Step 20 remains free of libtorrent, FFI, socket, HTTP server, file I/O, TimelineOverlay rendering, RSS automation, UI task screens, and concrete engine behavior.

## Capabilities

### New Capabilities

- `piece-priority-scheduler-contract`: Durable Step 20 contract for playback-aware piece priority planning, strategy profiles, priority plan persistence, and engine-neutral plan application handoff.

### Modified Capabilities

- `piece-priority-scheduler`: Refine the bootstrap priority scheduler specification into a durable plan/profile/application contract.
- `bt-task-core-contract`: Clarify that persisted BT task metadata and piece length provide scheduler input without concrete engine probing.
- `virtual-media-stream-contract`: Clarify that scheduler inputs use virtual stream descriptors and buffered range state without making range serving depend on scheduler behavior.
- `local-storage-foundation`: Add storage responsibilities for scheduler profiles, generated plans, and latest plan application events.
- `cache-invalidation-bus`: Add priority scheduler invalidation events for plan generation, plan application, plan rejection, and profile switching.

## Impact

- Affected code: `lib/src/streaming/piece_priority_scheduler.dart`, Storage contracts, cache invalidation bus, Phase 4 checker scripts, runtime validation, and deterministic tests.
- Affected specs: `piece-priority-scheduler-contract`, `piece-priority-scheduler`, `bt-task-core-contract`, `virtual-media-stream-contract`, `local-storage-foundation`, and `cache-invalidation-bus`.
- No concrete download engine, libtorrent binding, HTTP byte server, socket, FFI, platform file I/O, timeline overlay rendering, UI task screen, RSS automation, or advanced playback feature work is introduced.
