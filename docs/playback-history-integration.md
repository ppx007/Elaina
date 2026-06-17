# Playback History Integration

Step 44 adds the non-UI bridge from playback state to media-library history.
The bridge is intentionally small: it consumes `PlaybackStateSnapshot` values,
resolves `sourceUri` through `MediaLibraryCatalogRepository`, writes
`PlaybackHistoryEntry` values through `PlaybackHistoryStore`, and publishes the
existing `HistoryRecorded` cache event.

## Composition

App composition roots can wire the recorder without giving UI code storage row
models or player backend handles:

```dart
final recorder = PlaybackHistoryRecorder(
  catalogRepository: catalogRepository,
  historyStore: playbackHistoryStore,
  invalidationBus: cacheInvalidationBus,
);

final observer = PlaybackHistoryRecordingObserver(
  observable: playbackController,
  recorder: recorder,
);
```

Dispose the observer when the playback scope is torn down:

```dart
observer.dispose();
```

## Recording Rules

The recorder writes history only when the snapshot is durable enough to replay:

- lifecycle status is `playing`, `paused`, `buffering`, or `ended`
- `sourceUri` is present and resolves to a media-library catalog item
- timeline duration is present
- timeline position and duration are not negative

Snapshots that do not meet those rules return typed
`PlaybackHistoryRecordingResultKind.skipped` outcomes and do not write history
or publish invalidation events.

## Boundaries

This integration belongs to Domain media composition. It must not import Flutter
UI, concrete player bindings, media_kit/libmpv, SQLite packages, SQL, provider
clients, RSS, BT, network policy, diagnostics, or native player callbacks. The
only storage-facing dependency is the existing `PlaybackHistoryStore` contract.
