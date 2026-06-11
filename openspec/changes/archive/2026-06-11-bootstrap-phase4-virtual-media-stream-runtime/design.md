## Context

Phase 4 Step 18 archived the BT task core runtime: selected BT files, metadata, lifecycle state, transfer snapshots, and cache invalidation can now be represented without concrete torrent engine objects. The architecture plan lists Step 19 as `VirtualMediaStream`: range reads, buffered ranges, and piece map data where the player only sees a virtual stream abstraction.

The repository already has base `VirtualMediaStream` contracts and deterministic storage records. This change should therefore add a Step 19 runtime/bootstrap layer around those contracts rather than introducing concrete range servers, torrent engines, player adapters, or UI surfaces.

## Goals / Non-Goals

**Goals:**

- Compose selected BT task file records into deterministic virtual stream descriptors and replayable runtime projections.
- Persist stream lifecycle, buffered ranges, latest range failures, and restart-safe snapshots through Storage contracts.
- Publish post-mutation invalidation events after stream creation, range buffering, range failure, close, and failure transitions.
- Expose playback-safe handoff values that preserve player adapter independence.
- Provide validation and tests that prove Step 19 remains isolated from Step 20 scheduler, Step 21 timeline, concrete IO, UI, diagnostics, network, and native player bindings.

**Non-Goals:**

- Implementing `PiecePriorityScheduler` runtime, priority profiles, seek-window planning, or plan application.
- Implementing `TimelineOverlay` runtime, UI timeline layers, heat maps, or marker composition.
- Implementing HTTP servers, pipe servers, sockets, `dart:io`, `RandomAccessFile`, libtorrent, FFI, MPV/VLC, media-kit, platform channels, or native player adapters.
- Implementing RSS auto-download, online rule runtime, diagnostics center, storage migrations, or concrete database adapters.
- Fetching real bytes from a torrent engine. Step 19 records range availability and buffered state behind adapter-neutral contracts only.

## Decisions

### Runtime wraps existing stream contracts

Use a `VirtualMediaStreamRuntime` or equivalent bootstrap surface that composes the existing `VirtualMediaStreamRegistry`, `VirtualMediaStreamStore`, `BtTaskStore`, optional `CacheInvalidationBus`, and deterministic clock.

Alternative considered: expand `DeterministicVirtualMediaStreamRegistry` directly into the public runtime. That would blur low-level registry behavior with runtime status, projections, restart reconciliation, and validation concerns.

### Range delivery remains adapter-bound

The runtime records range availability, buffered ranges, and typed range failures. It must not pretend to serve bytes unless a pure byte-provider adapter boundary is explicitly introduced later.

Alternative considered: add concrete byte serving now. That would pull Step 19 into range server, socket, file, native engine, or platform work that belongs outside this slice.

### Stream snapshots are the contract for downstream slices

Step 20 and Step 21 should consume immutable virtual stream descriptors and buffered range snapshots. They must not call into stream mutation APIs or rely on engine internals.

Alternative considered: include scheduler/timeline-ready projections in the runtime. The safer boundary is data-only snapshots with no scheduler or overlay behavior.

### Playback handoff consumes virtual descriptors only

Playback source handoff may prepare an existing playback source from a virtual stream descriptor or virtual stream source value. It must reject direct BT task internals, piece maps, scheduler plans, timeline objects, and concrete engine handles.

Alternative considered: allow playback to open BT task/file records directly. That would violate the plan requirement that the player only recognizes virtual streams.

## Risks / Trade-offs

- [Risk] Tests accidentally validate Step 20/21 behavior because buffered ranges look like scheduler/timeline inputs. -> Mitigation: keep tests focused on descriptors, lifecycle, range availability, and immutable snapshots only.
- [Risk] `openRange` semantics imply concrete byte serving. -> Mitigation: validate typed failures or adapter-neutral availability; do not require actual byte chunks from filesystem, socket, or engine code.
- [Risk] Cache invalidation fires before durable state is readable. -> Mitigation: require post-mutation ordering in specs and tests.
- [Risk] Runtime imports concrete IO or UI dependencies during implementation. -> Mitigation: add a boundary checker forbidding concrete IO, UI, scheduler, timeline, diagnostics, network, and native player terms in Step 19 runtime files.

## Migration Plan

1. Add the Step 19 runtime/bootstrap surface and tests beside existing streaming contracts.
2. Reuse existing deterministic storage and cache invalidation contracts; extend only where Step 19 state requires it.
3. Export the runtime from the public barrel only after tests and checker coverage exist.
4. Keep existing virtual stream contracts source-compatible; this change should add behavior rather than remove existing APIs.
5. Rollback by removing the Step 19 runtime/bootstrap files, tests, checker, and spec deltas while leaving Step 18 BT task runtime intact.

## Open Questions

- Whether a future pure byte-provider adapter should be introduced before concrete range serving. This is intentionally not required for Step 19.
- Whether buffered range merging should remain exact-record based or normalize overlapping ranges. Step 19 can start with deterministic persisted records and defer compaction strategy.
