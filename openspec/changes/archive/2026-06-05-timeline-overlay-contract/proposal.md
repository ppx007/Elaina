## Why

Phase 4 has durable contracts for BT tasks, virtual media streams, and piece priority scheduling, but playback-facing surfaces still lack a stable timeline overlay read model for progress, buffered ranges, piece state, and future heat/marker layers. Step 21 completes the BT playback freeze by defining a presentation-facing overlay contract that UI can render later without depending on concrete download engines, scheduler internals, Flutter widgets, or native networking.

## What Changes

- Introduce a durable `timeline-overlay-contract` capability for read-only timeline snapshots, layer descriptors, range/marker projection, and overlay state persistence.
- Define overlay inputs from existing playback, virtual stream, and scheduler contracts while preserving one-way data flow into presentation read models.
- Extend the bootstrap `timeline-overlay` capability with Step 21 constraints for read-only layer composition, piece/buffer visualization, and boundary isolation.
- Extend related Phase 4 contracts only where they must expose timeline-safe snapshots or invalidation triggers.
- Keep concrete Flutter rendering, gesture handling, native engine integration, HTTP/pipe serving, diagnostics center behavior, and Phase 5 advanced playback out of scope.

## Capabilities

### New Capabilities
- `timeline-overlay-contract`: Durable Step 21 contract for timeline overlay read models, layer visibility/order, buffered and piece-state projections, marker/heat layers, and timeline invalidation events.

### Modified Capabilities
- `timeline-overlay`: Refine the bootstrap timeline overlay spec to align with the durable Step 21 contract boundary.
- `virtual-media-stream-contract`: Expose timeline-safe buffered range snapshots without making stream byte serving depend on overlay behavior.
- `piece-priority-scheduler-contract`: Expose timeline-safe plan/application snapshots without making scheduler planning depend on overlay behavior.
- `cache-invalidation-bus`: Add timeline overlay invalidation events for snapshot refresh and layer configuration changes.

## Impact

- Affected code: `lib/src/playback/` or equivalent playback-facing timeline contracts, `lib/src/streaming/` adapters/read models where timeline-safe snapshots are derived, `lib/src/foundation/storage/` if overlay preferences or snapshots need persistence, `lib/src/foundation/cache_invalidation/`, public barrel exports, focused tests, and Phase 4 checker scripts.
- Affected specs: new `timeline-overlay-contract` plus deltas for `timeline-overlay`, `virtual-media-stream-contract`, `piece-priority-scheduler-contract`, and `cache-invalidation-bus`.
- Dependencies: existing BT task, virtual media stream, piece priority scheduler, playback state/source handoff, storage, and cache invalidation contracts only; no concrete Flutter widget, libtorrent, MPV/VLC, HTTP server, socket, file I/O, FFI, or platform networking dependency.
