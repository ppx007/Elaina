## Why

Local media scanning now produces durable candidates, but the project still has no contract for turning those candidates into a persisted catalog. Without a media library repository, playback history, and binding state contracts, the app cannot reliably support continue-watching, deduplicated imports, or detail-page assembly.

## What Changes

- Add a media library persistence contract for storing, querying, updating, and removing `MediaLibraryItem` records.
- Add a scan-result import contract that converts `MediaScanCandidate` values into persisted library items with deduplication and batch result reporting.
- Add storage-backed contracts for playback history and provider binding state so they can survive restarts.
- Extend cache invalidation semantics for library, history, and binding mutations.
- Keep all persistence behavior behind Domain and Storage contracts; no UI, provider API, or network behavior is introduced here.

## Capabilities

### New Capabilities

- `media-library-persistence-contract`: persistent catalog repository, scan import pipeline, history persistence, and binding persistence contracts for the media library domain.

### Modified Capabilities

- `media-library-foundation`: adds persistent catalog, import, history, and binding requirements to the existing media library foundation.
- `local-storage-foundation`: extends the storage foundation to expose media library, playback history, and provider binding responsibilities.
- `cache-invalidation-bus`: adds library and history mutation events for derived-state refresh.

## Impact

Affected code includes `lib/src/domain/media/media_library.dart`, `lib/src/foundation/storage/storage_contracts.dart`, and the media/detail/cache invalidation contracts that consume library state. The change also introduces new storage-facing repository contracts and new OpenSpec specs for the persistence slice.
