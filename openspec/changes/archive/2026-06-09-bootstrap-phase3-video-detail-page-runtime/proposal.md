## Why

Phase 2 / Step 12 basic danmaku runtime is complete, so the architecture plan's next slice is Phase 3 / Step 13: the video detail page. Existing code defines `VideoDetailRepository`, `VideoDetailActionHandler`, `VideoDetailController`, UI-facing page contracts, media-library continue-watching contracts, and Bangumi provider metadata contracts, but there is no deterministic runtime that assembles cover, summary, episodes, continue-watching state, follow state, and detail actions through those Domain contracts.

## What Changes

- Add a deterministic Phase 3 video detail page runtime that loads detail data from approved metadata/provider and media-library contracts without direct UI, storage, network, RSS, BT, online-rule, subtitle-provider, or native-player coupling.
- Add concrete repository/action-handler behavior for cover, summary, episode list, selected/continue-watching state, follow/unfollow, refresh metadata, and episode selection using `VideoDetailViewData` and existing Domain action contracts.
- Add runtime/bootstrap state that composes Bangumi metadata values, provider bindings, playback history, playback source handoff, and cache invalidation events behind narrow Domain surfaces.
- Add focused tests and validation scripts proving Step 13 remains a detail-page runtime slice and does not expand into media-library scanning, subtitle provider, RSS engine, seasonal indexer, BT streaming, online rule sources, storage migration, concrete Flutter widgets, ProviderGateway internals, or MPV/VLC/native player bindings.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase3-video-detail-page-runtime`: Deterministic runtime/bootstrap for video detail page data assembly, metadata projection, episode actions, continue-watching integration, follow/unfollow state, cache invalidation, tests, and validation.

### Modified Capabilities
- `video-detail-page-contract`: Existing detail page contracts gain deterministic runtime, repository, action handler, lifecycle, metadata projection, and action-result requirements.
- `media-library-foundation`: Continue-watching and provider-binding contracts gain detail-page consumption requirements while remaining independent from scanner, storage implementation, provider internals, and UI state.
- `playback-source-handoff-contract`: Detail-page continue/select actions gain a requirement to resolve playable local media through existing handoff contracts rather than provider, UI, or native-player shortcuts.
- `repository-baseline`: The repository baseline gains a requirement that Step 13 video detail runtime remains optional Domain/UI enrichment and must not become a prerequisite for core playback, media scanning, subtitle provider, RSS, seasonal indexing, BT, online-rule, network, storage migration, diagnostics, or native player implementations.

## Impact

- Affected code: `lib/src/domain/detail/`, `lib/src/ui/detail/`, `lib/src/domain/media/`, `lib/src/domain/playback/playback_source_handoff.dart` consumers, `lib/src/foundation/cache_invalidation/`, public Dart barrel exports, focused detail runtime tests, runtime smoke checks, and validation scripts.
- Affected specs: new `phase3-video-detail-page-runtime` plus deltas for `video-detail-page-contract`, `media-library-foundation`, `playback-source-handoff-contract`, and `repository-baseline`.
- Dependencies: no concrete Flutter widget/page implementation, Bangumi HTTP transport, ProviderGateway implementation change, media-library scanner runtime, subtitle provider behavior, RSS engine behavior, seasonal indexer runtime, BT streaming, online-rule runtime, storage migration, MPV/VLC/native player binding, diagnostics, or network policy is introduced in this slice.
