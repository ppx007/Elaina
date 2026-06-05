## 1. Virtual stream storage persistence

- [x] 1.1 Add virtual stream descriptor, lifecycle, buffered range, and latest stream event storage records. Layers: Storage, Streaming
- [x] 1.2 Add `VirtualMediaStreamStore` contracts with deterministic implementations for stream descriptors, lifecycle state, buffered ranges, and latest range events. Layers: Storage
- [x] 1.3 Expose virtual media stream persistence responsibilities through `StorageFoundation`. Layers: Storage

## 2. Virtual stream orchestration

- [x] 2.1 Add virtual stream request, outcome, lifecycle, range availability, and failure contracts for stream creation, range ensuring, range opening, buffering, and closure. Layers: Streaming, Domain
- [x] 2.2 Add a deterministic `VirtualMediaStreamRegistry` that creates streams from persisted BT task metadata and selected file records. Layers: Streaming, Storage
- [x] 2.3 Add deterministic virtual stream behavior that persists buffered range snapshots and latest range events without owning concrete byte serving. Layers: Streaming, Storage
- [x] 2.4 Keep concrete HTTP servers, sockets, files, FFI, libtorrent bindings, piece priority scheduling, timeline overlay rendering, RSS automation, and UI task screens out of Step 19. Layers: Streaming, Tools

## 3. Invalidation and playback handoff boundaries

- [x] 3.1 Add cache invalidation events for virtual stream creation, buffered range updates, range failures, and stream closure. Layers: Foundation, Streaming
- [x] 3.2 Update playback source handoff contracts to accept virtual stream descriptors or source values without importing BT task core, download engine, scheduler, timeline, or byte-serving implementations. Layers: Domain, Playback
- [x] 3.3 Update Phase 4 boundary checkers to enforce no UI direct virtual stream/BT dependencies and no concrete byte-serving implementation dependencies. Layers: Tools

## 4. Verification and guardrails

- [x] 4.1 Add deterministic contract tests for virtual stream storage, stream creation from BT task metadata, buffered range persistence, range failure behavior, invalidation events, and playback handoff isolation. Layers: Test
- [x] 4.2 Update runtime validation to cover virtual stream persistence and deterministic registry orchestration. Layers: Tools
- [x] 4.3 Run analyzer, targeted virtual stream tests, full tests, runtime checks, Phase 4 checker, automation checker, and OpenSpec validation. Layers: Tools
