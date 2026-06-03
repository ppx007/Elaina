## Why

Playback surface, intent, and state contracts are now archived, but they have not been exercised by a real Flutter consumer. A minimal playback shell will validate those contracts at the widget boundary before native playback, provider data, or advanced rendering work begins.

## What Changes

- Add the minimal Flutter dependency and project structure needed to compile a playback shell.
- Add a mock-driven Flutter playback page that consumes playback surface descriptors, playback page intents, and playback state snapshots.
- Wire visible controls to dispatch plain Dart playback page intents and render deterministic mock state updates.
- Add widget or contract tests proving the shell consumes only the archived UI/Domain contracts.
- Keep the shell intentionally small and unstyled beyond functional layout.

## Capabilities

### New Capabilities
- `flutter-playback-shell-contract`: Minimal Flutter playback page shell that renders archived playback contracts with mock state and intent dispatch.

### Modified Capabilities

## Impact

- Affects `pubspec.yaml` by adding Flutter SDK dependencies required for shell compilation and tests.
- Adds Flutter shell code under a UI/presentation path that depends on existing playback page surface, intent, and state contracts.
- Adds Flutter/widget or closest available shell validation commands.
- Does not add MPV/native video surfaces, provider metadata, streaming, storage, gateway, network, danmaku, Anime4K, VLC fallback, diagnostics integration, navigation shell, routing, full theming, or production state management.
