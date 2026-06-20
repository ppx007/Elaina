## 1. Parser and Registry Runtime

- [x] 1.1 Add deterministic SRT parser implementation behind `SubtitleParser` in the Playback subtitle layer.
- [x] 1.2 Add deterministic WebVTT parser implementation behind `SubtitleParser` in the Playback subtitle layer.
- [x] 1.3 Add deterministic basic ASS dialogue parser implementation behind `SubtitleParser` in the Playback subtitle layer, leaving advanced styling out of scope.
- [x] 1.4 Add parser registry construction and unsupported-format normalization for SRT, VTT, and ASS in the Playback subtitle layer.

## 2. Local Scanner and Basic Subtitle Runtime

- [x] 2.1 Add deterministic media-adjacent subtitle scanner inputs and candidate normalization in the Playback subtitle layer without Provider, Storage, Streaming, Network, native player, or UI dependencies.
- [x] 2.2 Add `BasicSubtitleRuntime` or equivalent runtime composition for parser registry, local scanning, track loading, selected-track state, offset handling, and active-cue lookup.
- [x] 2.3 Add lifecycle-safe runtime result types for loaded, selected, unsupported, failed, and disposed subtitle operations.
- [x] 2.4 Ensure runtime snapshots defensively preserve loaded tracks, selected track identity, active cues, offset, warnings, and failure state.

## 3. Domain and Playback State Integration

- [x] 3.1 Extend Domain/Playback-safe subtitle state surfaces so playback consumers can observe available subtitle tracks and active cue descriptors without Flutter, Provider, Storage, Streaming, Network, diagnostics, or native binding types.
- [x] 3.2 Wire subtitle state into playback page foundation descriptors indirectly, preserving UI ownership of rendering and preventing Domain/Playback imports from UI shell types.
- [x] 3.3 Export only contract-safe parser, runtime, scanner, and state surfaces through `lib/elaina.dart` without exposing concrete provider, storage, streaming, network, native player, or Flutter shell dependencies.

## 4. Tests and Validation

- [x] 4.1 Add focused parser tests for SRT, WebVTT, and basic ASS timing/text normalization, empty input, warnings, and unsupported format behavior.
- [x] 4.2 Add focused runtime tests for construction, scanner discovery, load/select operations, player-clock offset cue resolution, immutable snapshots, and disposed operation results.
- [x] 4.3 Extend or add a subtitle runtime checker script that rejects Flutter UI, Provider implementation, Gateway, Storage, Streaming, Network, diagnostics UI, native player, BT, online-rule, and advanced caption dependencies in the Step 9 runtime slice.
- [x] 4.4 Extend runtime smoke validation to cover the Phase 2 basic subtitle runtime without reducing Phase 0 or Phase 1 checks.
- [x] 4.5 Run `openspec validate "bootstrap-phase2-basic-subtitle-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused subtitle/runtime tests, subtitle runtime checker scripts, and relevant existing player-core checks.
