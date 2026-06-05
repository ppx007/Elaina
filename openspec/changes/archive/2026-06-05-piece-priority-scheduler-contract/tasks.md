## 1. Priority scheduler storage persistence

- [x] 1.1 Add scheduler strategy profile, generated plan, plan rule, and latest application event storage records. Layers: Storage, Streaming
- [x] 1.2 Add `PiecePrioritySchedulerStore` contracts with deterministic implementations for profiles, plans, rules, and application events. Layers: Storage
- [x] 1.3 Expose piece priority scheduler persistence responsibilities through `StorageFoundation`. Layers: Storage

## 2. Priority planning contracts

- [x] 2.1 Add priority plan request, outcome, failure, application outcome, and persisted plan identity contracts. Layers: Streaming
- [x] 2.2 Add deterministic piece map derivation from persisted BT task metadata and selected file records. Layers: Streaming, Storage
- [x] 2.3 Add deterministic scheduler behavior for first pieces, tail pieces, playback windows, seek targets, profile lookahead, and buffered-range avoidance. Layers: Streaming, Storage
- [x] 2.4 Add engine-neutral plan application recording without concrete libtorrent, FFI, socket, HTTP server, file I/O, platform networking, UI, or TimelineOverlay behavior. Layers: Streaming, Tools

## 3. Invalidation and Phase 4 boundaries

- [x] 3.1 Add cache invalidation events for priority plan generation, plan application, plan rejection, and scheduler profile switching. Layers: Foundation, Streaming
- [x] 3.2 Update Phase 4 boundary checkers to require scheduler storage/planning/application terms and forbid concrete engine, UI, TimelineOverlay rendering, RSS automation, and advanced playback dependencies. Layers: Tools
- [x] 3.3 Preserve playback and virtual stream isolation so Playback does not import scheduler contracts and VirtualMediaStream does not depend on scheduler behavior for range serving. Layers: Playback, Streaming, Tools

## 4. Verification and guardrails

- [x] 4.1 Add deterministic contract tests for scheduler storage, profile persistence, piece-map derivation, playback-window planning, seek reprioritization, buffered-range avoidance, plan rejection, plan application events, and boundary isolation. Layers: Test
- [x] 4.2 Update runtime validation to cover deterministic scheduler planning and plan application recording. Layers: Tools
- [x] 4.3 Run analyzer, targeted scheduler tests, full tests, runtime checks, Phase 4 checker, automation checker, and OpenSpec validation. Layers: Tools
