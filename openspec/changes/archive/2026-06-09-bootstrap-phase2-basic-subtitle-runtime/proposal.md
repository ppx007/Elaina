## Why

Phase 1 froze the player-core runtime for Steps 5-8; the architecture plan's next slice is Phase 2 / Step 9, basic subtitles. Existing subtitle contracts define sources, parser interfaces, scanner interfaces, provider handoff, and offset intent, but there is no deterministic runtime that can parse SRT/VTT/ASS, scan media-adjacent subtitles, apply player-clock offsets, and expose subtitle state without provider or advanced rendering dependencies.

## What Changes

- Add a Phase 2 basic subtitle runtime that composes deterministic subtitle parser registry, local external subtitle scanner, subtitle track loading, active-cue resolution, and offset handling.
- Add concrete deterministic SRT, WebVTT, and basic ASS parser implementations behind existing `SubtitleParser` contracts.
- Add media-adjacent external subtitle scanning for already-selected local media values without filesystem traversal outside the media directory contract surface.
- Wire subtitle runtime state into playback-facing/domain-safe surfaces so playback page foundation can observe available tracks and active cues without importing Flutter widgets, provider systems, native player bindings, or advanced caption rendering.
- Extend validation and focused tests for parser behavior, scanner behavior, clock-relative offset behavior, runtime lifecycle, and layer isolation.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase2-basic-subtitle-runtime`: Runtime composition for deterministic SRT/VTT/ASS parsing, local external subtitle discovery, subtitle offset handling, active cue resolution, and lifecycle-safe subtitle state.

### Modified Capabilities
- `basic-subtitle-core`: Existing source/parser/scanner/offset contracts gain runtime-backed behavior requirements for concrete deterministic parsing, local scanning, offset application, and active-cue lookup.
- `playback-page-foundation`: Playback page foundation gains a requirement to consume subtitle availability and active-cue descriptors indirectly from runtime/domain surfaces without owning subtitle rendering internals.
- `playback-state-contract`: Playback state gains requirements for exposing subtitle-related snapshot data without Flutter, provider, or native binding types.
- `layered-architecture`: Layer boundaries gain explicit constraints for the subtitle runtime's allowed Domain/Playback dependencies and forbidden Provider/Gateway/Storage/Streaming/Network/UI/native dependencies.

## Impact

- Affected code: `lib/src/playback/subtitle/`, `lib/src/domain/subtitle/`, `lib/src/domain/playback/`, public Dart barrel exports, focused subtitle/runtime tests, and validation scripts.
- Affected specs: new `phase2-basic-subtitle-runtime` plus deltas for `basic-subtitle-core`, `playback-page-foundation`, `playback-state-contract`, and `layered-architecture`.
- Dependencies: no new native, Flutter UI, provider, gateway, storage, streaming, or network dependencies are introduced for the runtime slice.
