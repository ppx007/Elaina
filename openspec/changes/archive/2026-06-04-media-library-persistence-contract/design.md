## Context

Local media scanning is now contractually complete, but the discovered candidates still have nowhere to live. The codebase already has `MediaLibraryItem`, `PlaybackHistoryStore`, and `ProviderBindingStore` value and interface types in the Domain layer, plus a generic `StorageFoundation` in the Storage layer, but no contract that connects the two into a persistent catalog.

## Goals / Non-Goals

**Goals:**
- Define a persistent media library repository for catalog items.
- Define a scan-import pipeline that turns `MediaScanCandidate` values into stored items.
- Define storage-backed contracts for playback history and provider binding state.
- Make library, history, and binding mutations observable through cache invalidation events.

**Non-Goals:**
- No concrete SQLite or file-backed implementation.
- No UI assembly for the detail page.
- No provider API work, matching logic, or network access.
- No new playback engine behavior.

## Decisions

1. **Extend the storage foundation with media-specific stores.**
   The existing `StorageFoundation` already aggregates generic persistence responsibilities. This change should add media-library, playback-history, and provider-binding accessors rather than introducing a separate parallel storage root. That keeps persistence responsibilities discoverable and avoids a second injection surface.

2. **Model import as a batch contract, not a side effect of scanning.**
   Scanning discovers candidates; importing persists them. Keeping those steps separate makes deduplication, partial failure reporting, and future sync sources easier to reason about. A batch import result can report imported, skipped, and failed items explicitly.

3. **Use URI plus fingerprint as the deduplication surface.**
   URI is the primary identity for local files, while fingerprint is the fallback when paths move. This is narrower than provider metadata matching and keeps the contract local-file focused. Alternative keys based on provider binding are rejected because they would couple persistence to provider state.

4. **Keep playback history and provider binding as first-class repositories.**
   They already exist as Domain interfaces, so the change should define storage-backed repositories that satisfy those interfaces instead of making callers talk to generic key/value storage.

5. **Publish state changes through cache invalidation events.**
   Catalog mutation should invalidate derived views by event, not by direct cross-module mutation. New events for library and history changes are enough for now; provider binding already has a base event shape to extend.

## Risks / Trade-offs

- [Broader spec surface] → The change touches several specs, but that is preferable to leaving the media catalog split across ad hoc contracts.
- [Dedup ambiguity] → Use a documented primary/secondary key order so import behavior stays deterministic.
- [Storage foundation expansion] → Adding media-specific accessors makes the storage root larger, but it keeps persistence discoverable and aligned with the existing architecture.
- [History recording ambiguity] → The contract should define the storage side of playback history clearly, even if the playback observer that writes it is implemented later.

## Migration Plan

1. Add the new persistence capability spec and delta specs.
2. Update the media library, storage foundation, and cache invalidation requirements.
3. Add tasks for the repository contracts, import pipeline, and storage-backed history/binding semantics.
4. Implement behind existing Domain and Storage boundaries without changing UI or provider dependencies.

## Open Questions

- Should the storage foundation expose separate getters for media library, playback history, and provider binding, or a grouped media persistence aggregate?
- Should import deduplicate by URI only, or treat fingerprint as a required secondary key for moved files?
- Should provider bindings keep single-binding lookup as a convenience method while adding multi-binding queries underneath?
