## Context

Phase 4 Step 18 completed durable BT task orchestration through `BtTaskCoreContract`, `BtTaskStore`, and BT invalidation events. Step 19 now needs to turn the existing `VirtualMediaStream` bootstrap into a durable range-read contract that Playback can consume without importing BT task internals, concrete download engines, piece schedulers, timeline overlays, or platform networking implementation.

The current `virtual_media_stream.dart` defines identifiers, descriptors, range requests, chunks, failures, a stream interface, and a registry interface. It does not yet define durable stream records, deterministic registry behavior, task metadata readiness checks, buffered range persistence, or stream invalidation events.

## Goals / Non-Goals

**Goals:**

- Persist virtual stream descriptors, lifecycle state, buffered ranges, and latest range events through Storage contracts.
- Add deterministic virtual stream registry behavior that creates streams only from persisted BT task metadata and valid task files.
- Preserve Playback/UI isolation by exposing only virtual stream descriptors or playback source abstractions to player-facing code.
- Add range request outcomes and typed failures for metadata unavailable, file unavailable, range unavailable, timeout, cancellation, and task failure.
- Publish stream invalidation events when streams are created, buffered ranges change, range failures occur, or streams are closed.
- Extend runtime validation, deterministic tests, and Phase 4 boundary checkers for Step 19.

**Non-Goals:**

- No concrete libtorrent, FFI, socket, HTTP server, file I/O, platform networking, or native engine implementation.
- No PiecePriorityScheduler refinement, priority plan application, or piece-window strategy behavior.
- No TimelineOverlay refinement or visual progress-layer rendering.
- No RSS auto-download, online rule runtime, diagnostics center expansion, UI task screen, or advanced playback feature work.
- No guarantee of iOS long-background BT download behavior.

## Decisions

1. **Use a dedicated virtual stream storage contract.**
   Add Storage-layer records for stream descriptors, lifecycle, buffered ranges, and latest stream events instead of overloading `BtTaskStore`. This keeps task state and stream state separately queryable while still referencing `BtTaskId` and `BtFileIndex`.

2. **Make stream creation depend on persisted task metadata.**
   `DeterministicVirtualMediaStreamRegistry` should reject stream creation when metadata or file records are absent. This avoids raw adapter probing and makes restart behavior deterministic.

3. **Keep byte serving abstract.**
   The change defines range contracts and deterministic buffering behavior, but does not create an HTTP server, local file, socket, or native byte provider. Concrete byte serving remains an adapter responsibility in later implementation work.

4. **Publish coarse stream invalidation events.**
   Events should identify stream id, task id, file index, range, and failure kind as needed, but they must not carry raw bytes or engine objects.

5. **Pair playback handoff with virtual stream descriptors, not BT tasks.**
   Playback source handoff can accept a virtual stream descriptor/source abstraction while continuing to reject direct BT task, piece map, or download-engine dependencies.

## Risks / Trade-offs

- **Risk: Range contract accidentally becomes an HTTP server design.** → Mitigation: checker forbids `dart:io`, `HttpServer`, `Socket`, `RandomAccessFile`, `ffi`, and concrete engine terms in streaming contracts.
- **Risk: Stream state duplicates task file metadata.** → Mitigation: stream records reference task id and file index, while file length/path metadata remains owned by BT task storage.
- **Risk: Playback starts depending on BT task internals.** → Mitigation: playback handoff spec and checker require virtual stream abstractions rather than `BtTask`, `DownloadEngineAdapter`, or piece scheduler terms.
- **Risk: Step 19 bleeds into Step 20 or Step 21.** → Mitigation: explicitly exclude piece priority scheduling and timeline overlay requirements from this change.

## Migration Plan

- Add virtual stream storage records and deterministic in-memory store contracts.
- Extend `VirtualMediaStreamRegistry` and stream outcomes in `virtual_media_stream.dart`.
- Add stream invalidation events and runtime/checker coverage.
- Add deterministic tests for stream creation, range buffering, persistence, failure modes, and playback handoff isolation.
- Validate with analyzer, focused tests, runtime checks, Phase 4 checker, automation checker, and OpenSpec validation.

## Open Questions

- Whether persisted virtual stream lifecycle should use a separate `closed` terminal state or model closure only as latest event.
- Whether range availability should be represented as byte ranges only, or also expose piece-index hints for Step 20 without coupling Step 19 to scheduler behavior.
