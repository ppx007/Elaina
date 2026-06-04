## Why

The media library and playback handoff contracts can represent local media once it is selected, but the existing `MediaLibraryScanner` surface does not yet define precise local scan behavior. This change tightens that contract so file-backed scan scopes produce deterministic `MediaScanCandidate` values without adding storage persistence, provider metadata, network fetching, native playback, or UI browsing.

## What Changes

- Refine the existing `MediaLibraryScanner` contract for deterministic local file scan scopes, candidate discovery, progress events, cancellation, and normalized scan failures.
- Define scan-scope normalization for file roots, extensions, recursion, and exclude patterns before concrete filesystem traversal exists.
- Add scanner failure taxonomy expectations so unsupported roots, excluded entries, unreadable entries, and cancellation do not collapse into free-form messages.
- Keep scanner output Domain-owned by reusing existing `LocalMediaIdentity`, `MediaScanCandidate`, `MediaScanResult`, and `MediaScanEvent` values.
- Require scanner-produced candidates to preserve handoff invariants: non-empty file URI, non-empty basename, non-negative size, and no scanner-owned `PlaybackSource` construction.
- Preserve layer boundaries: scanner contracts must not import Provider, Gateway, Storage implementation, Streaming, Network, UI, MPV/native bindings, online rule runtimes, Bangumi, Dandanplay, RSS, BT, diagnostics, danmaku, Anime4K, or VLC fallback code.

## Capabilities

### New Capabilities
- `local-media-scanner-contract`: Contract refinement for existing `MediaLibraryScanner` local file scan scopes, deterministic candidate discovery, progress/cancellation semantics, and normalized scan failures.

### Modified Capabilities
- `media-library-foundation`: Existing scan scope, result, failure, event, and scanner contracts must gain clearer local scan semantics without provider metadata or storage-backed state.
- `playback-source-handoff-contract`: File-backed scan candidates produced by the scanner must preserve explicit handoff invariants.

## Impact

- Affects Domain media contracts and tests around scan-scope normalization, scan candidates, scan events, cancellation, and typed failures.
- Affects playback source handoff validation because scanner-produced candidates should feed the existing local file handoff path.
- Does not add concrete filesystem traversal, database persistence, provider matching, gateway traffic, network clients, native player bindings, platform permissions, metadata probing, thumbnail extraction, or Flutter UI.
