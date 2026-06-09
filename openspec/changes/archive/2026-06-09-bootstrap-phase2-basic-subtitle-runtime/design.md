## Context

The architecture plan orders the next implementation slice after Phase 1 player core as Phase 2 / Step 9: basic subtitles. The repository already contains contract-level subtitle surfaces for sources, parser interfaces, local scanner interfaces, provider handoff, and player-clock offset resolution, but those surfaces are not yet composed into a deterministic runtime with concrete SRT/VTT/ASS parsing or local subtitle attachment behavior.

This change follows the existing Phase 0 and Phase 1 bootstrap pattern: add a small runtime composition layer, deterministic implementations for tests and smoke checks, focused validators, and OpenSpec deltas. It must preserve the 8-layer boundary: subtitle parsing and cue resolution live in Playback contracts/runtime, domain-facing subtitle state can be consumed by playback page surfaces, and UI/native/provider/storage/streaming/network integrations remain outside this slice.

## Goals / Non-Goals

**Goals:**

- Provide deterministic SRT, WebVTT, and basic ASS parser implementations behind the existing `SubtitleParser` interface.
- Provide a deterministic parser registry and local external subtitle scanner suitable for tests and offline validation.
- Compose a `BasicSubtitleRuntime` or equivalent Phase 2 runtime surface that can load subtitle tracks, expose available tracks, resolve active cues from a player-clock snapshot plus offset, and normalize unsupported/disposed/error states.
- Expose only framework-neutral, contract-safe subtitle runtime surfaces through Domain/Playback/public barrels.
- Extend tests and validation scripts so parser behavior, local scanning, offset timing, lifecycle behavior, and layer isolation are executable.

**Non-Goals:**

- No Flutter subtitle rendering widgets, overlay positioning, styling UI, `MaterialApp`, platform views, or shell visual polish.
- No advanced caption rendering, dual subtitles, PGS rendering, ASS enhancement pipeline, or GPU/video enhancement coupling.
- No Bangumi, Dandanplay, online subtitle provider runtime, provider gateway traffic, storage-backed subtitle cache, network retrieval, or diagnostics-center integration.
- No native MPV/libmpv/media-kit subtitle APIs, VLC fallback, or platform channels.

## Decisions

1. **Keep concrete parsers in Playback subtitle runtime, not UI or Domain.**
   - Rationale: Subtitle cues and clock-relative lookup are playback concerns and already depend on `PlayerClockSnapshot` through `SubtitleCueResolver`.
   - Alternative considered: put parser implementations in Domain. Rejected because Domain should orchestrate user-facing flows, not own file-format parsing details.

2. **Use deterministic parser implementations instead of native player subtitle parsing.**
   - Rationale: Step 9 must be verifiable without native playback engines and must not depend on MPV/VLC/media-kit behavior.
   - Alternative considered: delegate parsing to MPV. Rejected because that would hide cue normalization and make contract tests native-dependent.

3. **Support a basic ASS subset as normalized text cues.**
   - Rationale: Basic subtitle core requires ASS cue coverage, but advanced ASS styling belongs to later advanced caption rendering contracts.
   - Alternative considered: full ASS style/layout rendering. Rejected as Step 24 scope.

4. **Make local subtitle scanning deterministic and directory-scoped.**
   - Rationale: Step 9 needs media-adjacent subtitle discovery while avoiding broad filesystem traversal, storage-backed library lookup, or platform-specific watchers.
   - Alternative considered: scan the entire library root. Rejected because it introduces filesystem policy and media-library responsibilities into the subtitle runtime.

5. **Expose subtitle availability and active cues through framework-neutral snapshots/descriptors.**
   - Rationale: Playback page foundation should observe subtitle state without importing parser/runtime internals or Flutter rendering types.
   - Alternative considered: have UI query parser/runtime directly. Rejected because it breaks the existing descriptor-driven playback page boundary.

## Risks / Trade-offs

- **[Risk] Basic ASS parser may not preserve complex styling or positioning.** → Mitigation: explicitly normalize basic dialogue text and leave style enhancement to advanced caption rendering.
- **[Risk] Subtitle timing edge cases differ across formats.** → Mitigation: add focused parser tests for decimal separators, WebVTT timestamps, ASS centiseconds, overlap, empty files, and warnings.
- **[Risk] Local scanning can become platform/filesystem-specific too early.** → Mitigation: constrain the first scanner behind an injectable directory listing abstraction or deterministic candidate list and validate no storage/network/provider imports.
- **[Risk] Runtime state could leak mutable cue lists.** → Mitigation: return immutable snapshots or defensive copies in runtime-facing APIs.
- **[Risk] Playback page foundation could overreach into rendering.** → Mitigation: keep this change to subtitle availability/active cue descriptors only; no widget or renderer ownership.

## Migration Plan

1. Add deterministic parser implementations and registry under `lib/src/playback/subtitle/`.
2. Add subtitle runtime composition and lifecycle/result types in Playback or Domain playback/subtitle composition according to existing import direction.
3. Extend playback/domain-safe state surfaces for subtitle availability and active cues without Flutter or provider types.
4. Add focused tests and smoke checker coverage.
5. Run `openspec validate "bootstrap-phase2-basic-subtitle-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused subtitle tests, and relevant checker scripts.

Rollback is straightforward before archive: remove the new runtime/parser/checker files and revert the OpenSpec change directory. No migration of persisted data is required.

## Open Questions

- The exact local scanner abstraction should be selected during implementation: an injected deterministic file candidate provider is preferred unless existing project utilities already define a better filesystem boundary.
- The runtime's final placement should follow import checks: parsing belongs in Playback; composition may live in Domain only if it does not force Playback to import Domain.
