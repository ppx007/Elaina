## 1. Domain Detail Runtime

- [x] 1.1 Add detail runtime result, failure, snapshot, and lifecycle value objects under `lib/src/domain/detail/` with deterministic disposed/unavailable behavior.
- [x] 1.2 Implement a deterministic `VideoDetailRepository` that assembles `VideoDetailViewData` from metadata subject/episode values, media-library provider bindings, playback history, and local media identities.
- [x] 1.3 Add metadata projection helpers that map Bangumi subject and episode values into `VideoDetailViewData` and `VideoDetailEpisode` without exposing provider runtime internals to UI contracts.
- [x] 1.4 Implement deterministic action derivation that keeps at most two primary actions and moves follow, unfollow, refresh metadata, open binding, and secondary episode operations behind secondary action boundaries.
- [x] 1.5 Implement a deterministic `VideoDetailActionHandler` for continue playback, episode selection, follow, unfollow, open binding, and refresh metadata with explicit success/ignored/unsupported/unavailable/failed outcomes.
- [x] 1.6 Route continue-playback and episode-selection actions through `PlaybackSourceHandoffContract` rather than constructing playback sources in UI, provider, media-library, storage, network, or native-player code.

## 2. Bootstrap, State Wiring, and Boundaries

- [x] 2.1 Add a `VideoDetailRuntime` or `VideoDetailBootstrap` composition entry point that wires repository, action handler, metadata provider, playback history store, provider binding store, playback source handoff, and cache invalidation bus.
- [x] 2.2 Publish cache invalidation events for detail metadata refresh, binding/follow state changes, and continue-watching input changes without introducing storage migrations or persistent detail caches.
- [x] 2.3 Keep video detail UI contracts framework-neutral and ensure Domain/runtime files do not import concrete Flutter widgets, ProviderGateway internals, storage implementations, RSS, subtitle provider, seasonal indexer, BT, online-rule, network policy, diagnostics, MPV/VLC, or native-player bindings.
- [x] 2.4 Export only safe video detail runtime and contract surfaces through `lib/elaina.dart` without exporting concrete Flutter page implementations.
- [x] 2.5 Preserve existing Phase 3 contract checker behavior while extending validation for the Step 13 runtime slice.

## 3. Tests and Validation

- [x] 3.1 Add focused detail runtime tests for metadata projection, episode list ordering, continue-watching state, binding/follow state, primary action limits, and deterministic `load`/`watch` behavior.
- [x] 3.2 Add action-handler tests for continue playback success, missing local media, unsupported handoff input, episode selection, follow, unfollow, refresh metadata, disposed behavior, and normalized failure outcomes.
- [x] 3.3 Add boundary tests or script checks proving UI does not import providers/storage/player internals and detail runtime does not own media scanning, subtitle provider, RSS, seasonal indexer, BT, online-rule, network, storage migration, diagnostics, or native player behavior.
- [x] 3.4 Add `tools/video_detail_runtime_check.dart` smoke validation covering runtime data assembly, action execution, playback handoff, provider binding precedence, and existing detail/library/Phase 2 smoke checks.
- [x] 3.5 Add `tools/check_video_detail_runtime.ps1` boundary validation that chains `check_detail_library_seasonal.ps1` and rejects forbidden Step 14+ / Phase 4+ / concrete UI / provider internals / storage implementation / native-player dependencies in Step 13 runtime files.
- [x] 3.6 Run `openspec validate "bootstrap-phase3-video-detail-page-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused detail runtime tests, video detail checker scripts, and existing detail/library, Bangumi, Dandanplay, subtitle, and danmaku runtime smoke checks.
