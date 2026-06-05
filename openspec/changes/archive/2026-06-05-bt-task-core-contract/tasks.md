## 1. BT task storage persistence

- [x] 1.1 Add BT task source, lifecycle status, metadata, file selection, transfer snapshot, and event records. Layers: Storage, Streaming
- [x] 1.2 Add `BtTaskStore` contracts with deterministic implementations for task state, metadata, files, status snapshots, and latest events. Layers: Storage
- [x] 1.3 Expose BT task persistence responsibilities through `StorageFoundation`. Layers: Storage

## 2. Domain BT task orchestration

- [x] 2.1 Add BT task core request, outcome, and failure contracts for create, metadata fetch, pause, resume, remove, and file selection commands. Layers: Streaming, Domain
- [x] 2.2 Add a deterministic BT task core contract that routes commands through `DownloadEngineAdapter`, validates `BtCapabilityMatrix`, and persists normalized state. Layers: Streaming, Storage
- [x] 2.3 Add status/event watch handoff that replays persisted task state and records adapter-emitted status, metadata, and lifecycle events. Layers: Streaming, Storage
- [x] 2.4 Keep concrete libtorrent, sockets, FFI, VirtualMediaStream byte ranges, piece-priority scheduling, timeline overlay, and RSS auto-download behavior out of Step 18. Layers: Streaming, Tools

## 3. BT task invalidation and capability boundaries

- [x] 3.1 Add cache invalidation events for BT task creation, metadata updates, lifecycle changes, file selection changes, and task removal. Layers: Foundation, Streaming
- [x] 3.2 Preserve platform capability gating for task management, metadata fetching, and long-background download support in Domain outcomes. Layers: Streaming
- [x] 3.3 Update Phase 4 boundary checkers to enforce no UI direct BT dependencies and no concrete engine implementation dependencies. Layers: Tools

## 4. Verification and guardrails

- [x] 4.1 Add deterministic contract tests for BT task storage, adapter command routing, metadata persistence, file selection persistence, capability failures, and invalidation events. Layers: Test
- [x] 4.2 Update runtime validation to cover BT task core persistence and deterministic adapter orchestration. Layers: Tools
- [x] 4.3 Run analyzer, targeted BT tests, full tests, runtime checks, Phase 4 checker, automation checker, and OpenSpec validation. Layers: Tools
