# Step 43 Video Detail Runtime Implementation

## Summary

Implement the first concrete, non-UI video-detail runtime path. This change
keeps UI ownership external while allowing video detail data and actions to be
assembled from real media-library storage, playback history, provider
bindings, and a metadata provider.

## Key Changes

- Add a storage/media-library backed video-detail repository and composition
  factory.
- Keep the existing deterministic seed path for acceptance tests and provider
  episode metadata projection.
- Build detail episodes from provider episode seeds when available; otherwise
  project bound local media catalog items into playable detail episodes.
- Reuse the existing detail action handler so continue playback, episode
  selection, follow, unfollow, and refresh metadata still go through
  Domain handoff and invalidation contracts.
- Extend tests and runtime checker coverage for SQLite-backed detail restart
  projection and non-UI smoke.
- Document Step 43 usage and boundaries.

## Non-Goals

- Do not modify `lib/src/ui/**`, `lib/main.dart`, or `windows/**`.
- Do not implement Flutter detail pages, routes, file picker UX, video
  surfaces, widgets, or visual state composition.
- Do not add a new Bangumi episode-list API that is not present in the current
  provider contract.
- Do not import SQLite packages, SQL, HTTP transports, MPV/VLC, BT, RSS,
  network policy, diagnostics, or provider runtime internals into Domain
  detail runtime files.

## Validation

- `flutter test test\domain\detail\video_detail_runtime_test.dart`
- New focused concrete video-detail storage tests.
- `powershell -ExecutionPolicy Bypass -File "tools\check_video_detail_runtime.ps1"`
- `openspec.cmd validate "step43-video-detail-runtime-implementation" --strict`
- `openspec.cmd validate --all`
- `dart analyze`
- `flutter analyze`
- `flutter test`
- `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`
