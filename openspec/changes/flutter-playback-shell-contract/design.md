## Context

The playback page now has three archived contracts: surface descriptors for visible controls, intents for user actions, and playback state snapshots for status/timeline/buffering/track state. The next boundary is a minimal Flutter shell that proves these contracts can drive a widget without importing native playback, providers, streaming, or later-phase systems.

## Goals / Non-Goals

**Goals:**
- Add only the Flutter project dependency and files required for a minimal playback page shell.
- Render playback state, visible controls, and secondary panel entry points from existing contracts.
- Dispatch playback page intents through a mock controller/driver and expose observable state changes for tests.
- Add widget or closest available shell tests that verify contract consumption and layer isolation.

**Non-Goals:**
- No MPV/libmpv/media-kit/VLC/native video surface or platform channel.
- No provider metadata, Bangumi, Dandanplay, RSS, BT streaming, danmaku, advanced subtitles, Anime4K, online rules, diagnostics integration, storage, gateway, or network behavior.
- No production navigation, routing, app shell, theming system, animation, responsive polish, Riverpod, Bloc, Provider package, or persistence.
- No real playback; all state and intents are mock-driven.

## Decisions

- Build a single playback page shell rather than a full app. This validates the contract boundary without committing to app navigation, theme, or platform packaging.
- Use a tiny mock driver owned by the UI shell. This keeps behavior observable in tests while avoiding native player or adapter coupling.
- Render controls from `PlaybackPageSurfaceDescriptor` and state from `PlaybackStateSnapshot`. Widgets must not infer capabilities from concrete adapters or import Playback layer internals.
- Dispatch only `PlaybackPageIntent` values. Button callbacks translate UI interaction into existing intent objects rather than calling adapters or native bindings.

## Risks / Trade-offs

- [Risk] Introducing Flutter expands project tooling scope -> Mitigation: keep the change to minimal dependencies, one shell widget, and tests.
- [Risk] UI starts depending on concrete playback internals -> Mitigation: add checker coverage for Flutter shell imports and use only archived UI/Domain contracts.
- [Risk] The shell becomes visual polish work -> Mitigation: constrain layout to functional rendering of state, controls, and mock intent effects.
- [Risk] Flutter SDK availability varies across environments -> Mitigation: document and run Flutter validation when available, while preserving Dart/OpenSpec validation as baseline.
