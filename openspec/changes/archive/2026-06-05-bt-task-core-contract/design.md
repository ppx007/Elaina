## Context

Step 18 follows the archived seasonal indexer contract and starts Phase 4 BT streaming work. Existing bootstrap contracts define `BtTaskSource`, `BtTaskMetadata`, `BtTaskStatus`, `BtTaskEvent`, `BtCapabilityMatrix`, and `DownloadEngineAdapter`, but task state is not yet durable and there is no Domain orchestration contract that normalizes adapter updates into Storage and invalidation events.

## Goals / Non-Goals

**Goals:**
- Persist BT task source, lifecycle, metadata, file selection, transfer status, and latest event state through Storage-layer contracts.
- Define a Domain BT task core contract that coordinates `DownloadEngineAdapter` task creation, metadata fetch, status/event watch, pause/resume/remove, and file selection commands.
- Publish cache invalidation events for BT task creation, metadata updates, lifecycle changes, file selection changes, and removal.
- Preserve platform capability gating, especially for task management, metadata fetching, and long-background download support.

**Non-Goals:**
- No concrete libtorrent, FFI, socket, file descriptor, or native download-engine implementation.
- No VirtualMediaStream byte-range serving or media cache read path.
- No PiecePriorityScheduler profile or plan-application behavior.
- No TimelineOverlay rendering or UI download page.
- No RSS auto-download, rule-source, or automation-triggered BT enqueueing.

## Decisions

1. **BT task state belongs to Storage, not the engine.**
   `DownloadEngineAdapter` can emit task state, but durable records should live behind Storage contracts so Domain can replay task status after restart and avoid depending on engine-owned persistence.

2. **Domain owns command orchestration.**
   A BT task core contract should validate capabilities, call adapter commands, persist normalized status/events, and publish invalidation events. UI and Playback continue to depend on Domain/Playback abstractions rather than task engine internals.

3. **Capability failures are contract outcomes.**
   Unsupported task management, metadata fetching, or long-background download should be represented as typed outcomes or failures rather than hidden booleans. This preserves the iOS background-download constraint and keeps UI feature availability declarative.

4. **Step 18 stops before streaming bytes.**
   File selection can identify a streaming target, but actual range serving, buffered ranges, piece maps, and scheduler plans stay in later Step 19-20 changes.

5. **Invalidation events describe business state, not engine callbacks.**
   Events such as `BtTaskCreated`, `BtMetadataUpdated`, and `BtTaskLifecycleChanged` should publish normalized task identifiers and state fields instead of concrete adapter event objects.

## Risks / Trade-offs

- [Engine-specific metadata leaks into Domain] -> Persist only normalized BT task metadata and file descriptors already defined by Streaming contracts.
- [Step 18 grows into full streaming playback] -> Keep VirtualMediaStream, piece scheduling, and timeline overlay behavior as explicit non-goals.
- [Unsupported background behavior is overpromised] -> Gate lifecycle commands through `BtCapabilityMatrix` and expose capability failures in Domain outcomes.
- [Storage records duplicate adapter state] -> Accept normalized replay state now; concrete engine synchronization can be refined by adapter implementations later.

## Migration Plan

1. Add BT task Storage records/stores and expose them through `StorageFoundation`.
2. Add Domain BT task core orchestration contracts and deterministic implementation around `DownloadEngineAdapter`.
3. Add BT task cache invalidation events for lifecycle, metadata, file selection, and removal mutations.
4. Add deterministic contract tests, runtime validation, and Phase 4 checker guardrails.

## Open Questions

- None for the current contract boundary. Virtual stream range serving, piece-priority scheduling, timeline overlay projection, and automation-driven task enqueueing are deferred to later changes.
