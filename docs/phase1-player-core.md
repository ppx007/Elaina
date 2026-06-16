# Phase 1 Player Core Contracts

This document records the implementation boundary for `bootstrap-player-core`, covering Phase 1 / Step 5-8 from `docs/celesteria-architecture-plan.md`.

## Scope

1. MPV adapter facade for local file, HTTP, and HLS playback sources.
2. Playback capability matrix for adapter and platform capability decisions.
3. Playback page foundation driven by Domain and Playback contracts.
4. Audio and subtitle track discovery and switching contracts.

## Binding Policy

The MPV facade is the first playback target, but it must not claim local file, HTTP, or HLS playback support unless a concrete native binding is available behind the `PlayerAdapter` contract. In this workspace, the Dart/Flutter/native playback toolchain is not available, so the facade reports unsupported capability states until a binding is introduced.

For concrete local file playback, app composition roots should use
`mediaKitLocalFilePlayerRuntimeComposition(...)` and pass the returned
`PlayerRuntimeCompositionContract` into
`PlayerCoreBootstrap.withComposition(...)`. This keeps concrete media_kit/libmpv
details in the Playback implementation while Domain runtime files consume only
binding and capability contracts.

## UI Policy

Playback UI code consumes Domain and Playback contracts. It must not import concrete player engines or native bindings. Unsupported controls and secondary panel entries are hidden or disabled based on the capability matrix.

## Excluded From This Slice

- Provider metadata and matching.
- Danmaku rendering.
- Advanced subtitle rendering and subtitle provider integration.
- BT streaming and timeline overlays.
- Video enhancement and Anime4K.
- VLC fallback and platform adapter implementations.
- Diagnostics center.
