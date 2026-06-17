# Step 44 Playback History Integration

## Summary

Add the non-UI playback history integration layer that records playback
progress from Domain playback state into the existing media-library history
contracts. This change keeps UI ownership external while allowing real
storage-backed continue-watching state to be updated from playback runtime
snapshots.

## Key Changes

- Add a Domain media playback-history recorder that consumes
  `PlaybackStateSnapshot` values.
- Resolve local media by playback `sourceUri` through the media-library catalog
  repository rather than requiring UI to pass storage row models.
- Persist progress through `PlaybackHistoryStore` and publish existing
  `HistoryRecorded` invalidation events.
- Add an observer wrapper that can be attached to a `PlaybackControllerContract`
  by an app composition root.
- Add SQLite-backed restart tests and non-UI checker coverage.
- Document Step 44 usage and boundaries.

## Non-Goals

- Do not modify `lib/src/ui/**`, `lib/main.dart`, or `windows/**`.
- Do not implement continue-watching pages, playback pages, widgets, routes,
  file picker UX, video surfaces, or UI state composition.
- Do not add player polling, platform timers, media_kit/libmpv calls, or native
  player callbacks to the history recorder.
- Do not import SQLite packages, SQL statements, provider transports, RSS, BT,
  network policy, diagnostics, MPV, VLC, or Flutter UI into Domain media
  history integration files.

## Validation

- `flutter test test\domain\media\playback_history_integration_test.dart`
- `flutter test test\domain\media\media_library_concrete_runtime_test.dart`
- `powershell -ExecutionPolicy Bypass -File "tools\check_media_library_runtime.ps1"`
- `openspec.cmd validate "step44-playback-history-integration" --strict`
- `openspec.cmd validate --all`
- `dart analyze`
- `flutter analyze`
- `flutter test`
- `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`
