# Media Library Runtime Implementation

Step 42 adds the first concrete, non-UI media-library runtime path.

## Composition

Use `storageBackedMediaLibraryBootstrap(...)` from the app composition root:

```dart
final bootstrap = storageBackedMediaLibraryBootstrap(
  storage: sqliteStorageFoundation,
  invalidationBus: cacheInvalidationBus,
  scanner: LocalFileMediaLibraryScanner(),
);
```

The factory adapts existing `StorageFoundation` stores into the Domain
`MediaLibraryRuntime` contracts:

- `MediaLibraryStore` -> `MediaLibraryCatalogRepository`
- `PlaybackHistoryRepository` -> `PlaybackHistoryStore`
- `ProviderBindingRepository` -> `ProviderBindingStore`

SQLite stays a Foundation/Storage implementation detail. Domain media code sees
storage contracts and runtime projections, not database handles or SQL.

## Local Scanner

`LocalFileMediaLibraryScanner` traverses file-system directories with `dart:io`,
filters using `MediaScanScope`, and emits existing `MediaScanEvent` values. It
does not implement UI file picking, thumbnails, metadata provider matching, or
hashing. File fingerprints remain optional and can be supplied by later scanner
enhancements.

## UI Boundary

UI remains external. UI code should pass user-selected roots into Domain media
contracts and consume `MediaLibraryRuntimeSnapshot`. It should not import
SQLite, storage row models, scanner internals, provider clients, BT engines, or
native player bindings.

## Smoke Path

The checker covers this non-UI flow:

```text
local directory -> LocalFileMediaLibraryScanner -> import -> SQLite-backed
storage -> refresh projection -> history/binding replay -> playback handoff
```

