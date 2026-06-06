## 1. Contract Models

- [x] 1.1 Define framework-neutral timeline overlay value types for snapshots, ranges, pieces, markers, heat values, layer ids, layer kinds, visibility, ordering, and rejection/failure kinds in the Playback-facing contract layer.
- [x] 1.2 Add deterministic overlay composition inputs for playback state snapshots, virtual stream descriptors/buffered ranges, and scheduler plan/application summaries without importing concrete UI, storage implementations, native playback, or streaming engines.
- [x] 1.3 Add overlay-safe storage contracts for layer visibility/order, selected overlay profile, and latest derived snapshot metadata if persistence is required by the implementation design.

## 2. Overlay Composition

- [x] 2.1 Implement deterministic timeline overlay composition from contract-safe inputs into immutable snapshot read models.
- [x] 2.2 Implement layer projection for playback progress, buffered ranges, piece states, scheduler priority windows, markers, and heat data as independently identifiable layers.
- [x] 2.3 Implement typed rejection paths when required playback, virtual stream, or scheduler inputs are unavailable, without probing concrete engines or byte-serving implementations.

## 3. Invalidation and Exports

- [x] 3.1 Add timeline overlay invalidation events for snapshot refresh, layer configuration changes, and overlay composition rejection.
- [x] 3.2 Expose timeline overlay contracts through the appropriate public barrels while preserving 8-layer boundaries.
- [x] 3.3 Update Phase 4 documentation/checker terms so TimelineOverlay remains Step 21-scoped and does not require Flutter rendering, libtorrent, native playback, sockets, files, FFI, RSS automation, diagnostics, or Phase 5 advanced playback.

## 4. Verification

- [x] 4.1 Add focused tests for snapshot composition, independent layer visibility/order, buffered and piece projections, scheduler priority projection, rejection paths, and event publication.
- [x] 4.2 Update runtime validation to exercise the timeline overlay contract and guard against forbidden dependencies.
- [x] 4.3 Run `openspec validate "timeline-overlay-contract" --strict`, `openspec validate --all`, `dart analyze`, `flutter test`, `dart tools/player_core_runtime_check.dart`, and Phase 4 checker scripts.
