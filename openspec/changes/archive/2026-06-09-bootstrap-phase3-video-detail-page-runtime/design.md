## Context

The architecture plan places Phase 3 / Step 13 immediately after the completed Phase 2 subtitle, Bangumi, Dandanplay, and basic danmaku runtime slices. Step 13 is the video detail page: cover, summary, episode selection, continue playback, and follow state with data sourced from metadata providers.

Current code already has the contract layer: `VideoDetailRepository`, `VideoDetailActionHandler`, `VideoDetailController`, `VideoDetailViewData`, `VideoDetailEpisode`, `VideoDetailPageContract`, `PlaybackHistoryStore`, `ProviderBindingStore`, `BangumiProvider`, and `PlaybackSourceHandoffContract`. The missing piece is a deterministic runtime that assembles these contracts into a usable detail-page state and action surface without implementing a concrete Flutter page or leaking provider/storage/network/native player details into UI.

This change is the first Phase 3 runtime slice. It should reuse Phase 2 runtime patterns: deterministic in-memory implementations, lifecycle-safe snapshots/results, narrow Domain bridges, focused tests, smoke scripts, and PowerShell boundary checks.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic `VideoDetailRepository` runtime that assembles `VideoDetailViewData` from Bangumi metadata values, media-library provider bindings, playback history, and local media identities.
- Provide a deterministic `VideoDetailActionHandler` for continue playback, episode selection, follow, unfollow, open-binding, and refresh-metadata actions through existing Domain contracts.
- Add a `VideoDetailRuntime`/bootstrap entry point that composes repository, action handler, metadata provider, playback history, provider bindings, playback source handoff, and cache invalidation bus behind safe Domain-facing surfaces.
- Preserve detail-page UX constraints: at most two primary actions, episode cards carry one selected action path, and advanced operations remain secondary actions.
- Add tests, smoke checks, and boundary validation proving the runtime remains isolated from concrete Flutter widgets, ProviderGateway internals, storage migrations, RSS, subtitle provider, seasonal indexer, BT, online-rule, network policy, diagnostics, MPV/VLC, and native player bindings.

**Non-Goals:**

- No Flutter screen/page/widget implementation beyond existing framework-neutral page contracts.
- No Bangumi HTTP transport, OAuth changes, progress sync policy changes, ProviderGateway implementation changes, account/session storage, or network client behavior.
- No media-library scanner/import runtime, persistent catalog migration, subtitle provider runtime, RSS engine runtime, seasonal indexer runtime, BT playback, online rule source parsing, WebView challenge handling, DNS policy, diagnostics center, Anime4K, VLC fallback, or MPV/native player changes.
- No storage schema migration or database-backed repository implementation.
- No automatic metadata matching queue or seasonal catalog behavior; user-confirmed bindings remain a media-library contract concern.

## Decisions

1. **Build Step 13 as a Domain runtime, not a Flutter page.**
   - Rationale: the existing `VideoDetailPageContract` is a thin UI-facing wrapper around Domain contracts, and project rules forbid UI from directly depending on Bangumi, Dandanplay, ProviderGateway, storage, RSS, or player internals.
   - Alternative considered: implement a Flutter detail screen now. Rejected because the architecture plan asks for runtime foundations first and the current codebase validates framework-neutral contracts before concrete UI.

2. **Use Bangumi provider values as metadata input but keep runtime composition in Domain.**
   - Rationale: Step 13 data comes from `MetadataProvider`, and Bangumi is the only implemented metadata provider runtime. A Domain bridge can project `BangumiSubject` and `BangumiEpisode` into `VideoDetailViewData` while preserving provider isolation.
   - Alternative considered: make `VideoDetailRepository` depend on `BangumiProviderRuntime` directly. Rejected because runtime implementation details and auth/progress behavior should stay behind provider interfaces.

3. **Read continue-watching and follow state from media-library contracts.**
   - Rationale: `ContinueWatchingState`, `PlaybackHistoryStore`, `ProviderBinding`, and `ProviderBindingStore` already encode playback history and user-confirmed binding semantics. Detail runtime should consume them rather than inventing a parallel state model.
   - Alternative considered: store detail-specific follow/progress fields in the detail runtime. Rejected because it would duplicate media-library authority and make future Step 14 harder.

4. **Resolve playback actions through `PlaybackSourceHandoffContract`.**
   - Rationale: selected/continue playback must stay playback-capability aware and avoid bypassing handoff invariants. The handoff contract already converts local media identities into `PlaybackSource` values.
   - Alternative considered: let the detail action handler construct playback sources directly. Rejected because it would create a provider/UI/local-media shortcut around Playback contracts.

5. **Emit cache invalidation events for binding/history/metadata updates without owning persistence.**
   - Rationale: existing `CacheInvalidationBus` has binding and history events. Step 13 should publish detail-relevant changes so future views can refresh, but it should not introduce storage migrations.
   - Alternative considered: add a detail-specific persistent cache. Rejected for this slice because deterministic runtime and existing store contracts are enough to prove the detail flow.

6. **Keep action output deterministic and testable.**
   - Rationale: detail page primary actions are explicitly limited to two. The runtime can deterministically derive primary/secondary actions from whether continue-watching, selected episode, and follow state exist.
   - Alternative considered: leave action derivation entirely to future UI. Rejected because the current contract already exposes `VideoDetailActionSet` and `hasValidPrimaryCount`.

## Risks / Trade-offs

- **[Risk] Detail runtime expands into media-library runtime.** → Mitigation: tasks and checker scripts forbid scan/import/storage migration terms in detail runtime files; Step 14 remains separate.
- **[Risk] Domain leaks provider implementation details.** → Mitigation: depend on provider interfaces/value contracts only, keep Bangumi projection helpers narrow, and validate no `ProviderGateway` or concrete runtime internals are imported by UI/detail surfaces.
- **[Risk] Continue playback is ambiguous when no local media exists.** → Mitigation: define explicit unavailable/unsupported action outcomes and require tests for missing local media, missing history, and unsupported handoff inputs.
- **[Risk] Follow/unfollow semantics conflict with Bangumi progress sync.** → Mitigation: define follow/unfollow as local provider-binding state changes plus cache invalidation only; Bangumi progress sync remains Phase 2 metadata/progress behavior.
- **[Risk] Primary action count regresses as actions grow.** → Mitigation: require runtime tests and checker terms around `hasValidPrimaryCount` and action derivation.

## Migration Plan

1. Add detail runtime values, repository implementation, action handler, action outcomes, and runtime lifecycle under `lib/src/domain/detail/`.
2. Add narrow metadata projection helpers from Bangumi provider values to `VideoDetailViewData` without importing ProviderGateway or provider implementation internals into UI.
3. Wire continue-watching, selected episode, follow/unfollow, and binding state through existing `PlaybackHistoryStore`, `ProviderBindingStore`, `PlaybackSourceHandoffContract`, and `CacheInvalidationBus` contracts.
4. Export safe runtime surfaces through `lib/elaina.dart` without exporting concrete Flutter page implementations.
5. Add focused tests, smoke check, and boundary checker script.
6. Run `openspec validate "bootstrap-phase3-video-detail-page-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused detail runtime tests, checker scripts, and existing detail/library/Phase 2 smoke checks.

Rollback before archive is deleting the new runtime/test/tool files and removing this change directory. No persisted schema or storage migration is introduced.

## Open Questions

- Whether follow/unfollow should later trigger remote Bangumi collection/progress sync should be designed in a separate metadata-progress change.
- Whether the eventual Flutter detail screen should own richer loading/error view state or consume a Domain snapshot type directly should wait for concrete UI implementation.
- Whether episode selection should prefetch subtitles/danmaku should remain out of scope until subtitle provider and media library runtime slices are implemented.
