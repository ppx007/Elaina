# Video Detail Runtime Implementation

Step 43 adds the first concrete, non-UI video-detail runtime path.

## Composition

Use `storageBackedVideoDetailBootstrap(...)` from the app composition root:

```dart
final bootstrap = storageBackedVideoDetailBootstrap(
  storage: sqliteStorageFoundation,
  metadataProvider: bangumiProvider,
  invalidationBus: cacheInvalidationBus,
);
```

The factory adapts existing storage-backed media-library contracts into
`VideoDetailRepository` and reuses the existing detail action handler:

- media catalog records provide local playable detail episodes
- playback history records provide continue-watching state
- provider binding records provide follow/binding state
- metadata provider subject lookup provides title and summary

If provider episode metadata is already available through
`BangumiVideoDetailSeed`, the runtime preserves provider episode ids, titles,
indexes, and optional cover URI. Without that seed, bound local catalog items
are projected as playable episodes using deterministic catalog ordering.

## Boundaries

UI remains external. UI code should consume `VideoDetailController`,
`VideoDetailViewData`, `VideoDetailActionResult`, and the documented bootstrap
entrypoint from composition code. It should not import storage row models,
provider transports, native player bindings, BT/RSS/network internals, or
scanner implementation details.

Database details stay in Foundation/Storage. Domain detail storage adapters
consume storage contracts and media-library adapters only.

