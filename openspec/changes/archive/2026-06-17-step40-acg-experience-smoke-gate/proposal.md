## Why

Steps 36-39 added concrete Bangumi, Dandanplay, OpenSubtitles, and playback
metadata bridge pieces. Step 40 closes Phase B by adding a non-UI ACG
experience smoke gate that proves those pieces compose into a deterministic
"local file can be enriched for playback" flow.

This change is intentionally not a new provider client and not an app shell.
It validates composition, gateway/cache use, failure normalization, and layer
boundaries before the project moves into storage/media-library work.

## What Changes

- Add a Domain ACG experience runtime that composes:
  - `AcgDataController` for Bangumi and Dandanplay provider access;
  - `SubtitleProviderRuntime` for provider subtitle discovery/cache handoff;
  - `PlaybackMetadataBridge` for subtitle/danmaku playback projections.
- Add a deterministic smoke request/result surface for local media enrichment.
- Add focused tests for full success, provider cache reuse, typed failures, and
  disposed behavior.
- Extend smoke/checker coverage for the full Step 36-40 ACG path.
- Keep `lib/src/ui/**`, `lib/main.dart`, `windows/**`, storage migrations,
  streaming engines, and native player bindings untouched.

## Impact

- Affected code is limited to Domain ACG composition, tests, tools/checkers,
  docs, public exports, and OpenSpec specs.
- Tests use deterministic providers/fake transports; no live network is
  required.
- UI can later consume the resulting Domain/Playback snapshots but remains
  externally owned.
