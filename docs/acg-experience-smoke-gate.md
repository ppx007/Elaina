# ACG Experience Smoke Gate

Step 40 closes the Phase B provider/playback path without adding UI code or live
network requirements. The smoke gate proves that the Step 36-39 pieces can be
composed into one deterministic local-media enrichment flow:

```text
Local media request
  -> AcgDataController
  -> SubtitleProviderRuntime
  -> PlaybackMetadataBridge
  -> PlaybackStateSnapshot
```

`AcgExperienceRuntime` is a Domain-owned composition surface. It accepts an
`AcgExperienceRequest`, requests optional Bangumi subject metadata, runs
Dandanplay filename matching, loads Dandanplay comments, discovers provider
subtitles, hands the selected subtitle candidate to the playback metadata
bridge, and returns an `AcgExperienceResult`.

The runtime deliberately chooses the first Dandanplay match and first provider
subtitle candidate only for deterministic smoke validation. Product UI remains
responsible for presenting candidate choice later; this change only verifies
that the lower layers produce stable values, cache behavior, and typed
failures.

## Boundaries

- No `lib/src/ui/**`, `lib/main.dart`, or `windows/**` files are part of this
  step.
- No concrete API clients are imported by `AcgExperienceRuntime`.
- Bangumi, Dandanplay, and subtitle traffic still pass through the existing
  provider runtime/gateway/cache surfaces.
- Playback projection goes through `PlaybackMetadataBridge`; the smoke gate does
  not own subtitle parsing, danmaku rendering, native player control, or video
  surfaces.
- Partial provider failures are returned as `AcgExperienceFailure` values
  instead of raw transport, parser, or gateway exceptions.

## Non-UI Validation

Run the focused smoke gate with:

```powershell
flutter test test\domain\acg\acg_experience_runtime_test.dart
dart run tools\elaina_tool.dart check module --module acg_data_experience
```

This validates the deterministic Step 36-40 composition path. A later UI-owned
playback page may consume the returned `PlaybackStateSnapshot` and metadata
snapshots, but UI implementation is outside this step.
