## Context

The current playback stack has framework-neutral playback controller contracts, page surface descriptors, page intents, playback state snapshots, and a minimal Flutter shell. The shell can mutate local mock state, but it does not yet prove that UI interaction can travel through a controller-facing orchestration boundary and return as observable playback state.

This change keeps the work inside UI, Domain, and Playback contract layers. It must not introduce native player surfaces, provider metadata, streaming systems, storage, gateway, network, diagnostics, app routing, persistence, production state management, or platform packaging.

## Goals / Non-Goals

**Goals:**
- Define the controller-facing contract needed to dispatch playback page intents and observe resulting playback state snapshots.
- Provide deterministic mock behavior that exercises play, pause, seek, stop, panel, and track-selection flows without native playback.
- Allow the Flutter shell to use a controller-driven driver while preserving the shell's UI-only dependency boundary.
- Extend automation so non-UI layers remain free of Flutter shell imports and Flutter package dependencies.

**Non-Goals:**
- No MPV, VLC, libmpv, media-kit, platform channels, video surfaces, or native adapter implementations.
- No provider, gateway, storage, streaming, network, RSS, Bangumi, Dandanplay, yuc.wiki, BT, danmaku, Anime4K, diagnostics, routing, persistence, or production state-management packages.
- No visual redesign of the playback shell.

## Decisions

1. Keep the controller contract framework-neutral.

   The controller boundary belongs below Flutter UI, so its observable state and command results must remain plain Dart contracts. This preserves the current direction of dependency: Flutter shell consumes contracts; Domain and Playback do not import Flutter.

2. Exercise the loop with deterministic mocks before native playback.

   A mock controller or driver bridge is enough to prove intent dispatch, state updates, surface resolution, and result reporting. Native adapters can later implement the same boundary after the contract is stable.

3. Update the Flutter shell through its driver abstraction.

   The shell should not learn about concrete player adapters. It should keep consuming a driver that exposes snapshot, surface, active panel, last result, and dispatch behavior, with one driver implementation backed by the controller contract.

4. Keep tests at the contract and widget boundary.

   Unit tests should verify controller intent handling and state observation. Widget tests should verify the shell renders controller-driven state and dispatches controls through the driver.

## Risks / Trade-offs

- Controller scope creep into native playback behavior -> Keep implementation deterministic and mock-only; only model command/result/state flow.
- Duplication between `PlaybackPageContract.dispatch` and the shell driver -> Reuse the page contract where possible instead of reimplementing capability checks in the shell.
- Flutter dependency leakage into Domain or Playback -> Extend checker coverage and keep controller files free of `package:flutter` and `dart:ui`.
- Premature state-management choice -> Use existing observer/listener-style contracts and avoid Provider, Riverpod, Bloc, or app-wide routing.
