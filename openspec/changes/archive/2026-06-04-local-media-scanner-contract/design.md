## Context

The current project has Domain media values for scan scopes, identities, scan candidates, scan results, scan events, and scanner cancellation. The playback source handoff can already prepare a file-backed `MediaScanCandidate` into a `LocalFilePlaybackSource`, but the existing `MediaLibraryScanner` contract does not yet define precise local scan semantics for scope normalization, failure taxonomy, cancellation, and handoff invariants.

This change defines the local scanner boundary before adding concrete filesystem traversal, platform permission handling, database persistence, provider matching, native playback probing, metadata extraction, or UI library browsing.

## Goals / Non-Goals

**Goals:**
- Specify how existing `MediaLibraryScanner` implementations normalize local scan scopes and produce `MediaScanCandidate` values through Domain media contracts.
- Normalize progress, completion, cancellation, and failure behavior so scanner callers do not infer scanner state from concrete platform exceptions or free-form strings.
- Prove scanner-produced file candidates remain valid inputs for the existing playback source handoff.
- Preserve layer isolation from Provider, Gateway, Storage implementation, Streaming, Network, UI, MPV/native bindings, and later ACG integrations.

**Non-Goals:**
- No new parallel scanner API, concrete filesystem walker, platform permission flow, file watcher, isolate scheduler, media probing, thumbnail generation, or metadata extractor.
- No SQLite/database persistence, playback history writes, provider binding, Bangumi matching, Dandanplay matching, RSS ingestion, or online rule parsing.
- No UI media-library page, playback queue, native MPV integration, BT streaming, diagnostics panel, or storage migration.

## Decisions

1. Refine `MediaLibraryScanner` instead of creating a parallel scanner API.

   The change should sharpen `MediaLibraryScanner`, `MediaScanScope`, `MediaScanCandidate`, `MediaScanResult`, `MediaScanFailure`, and `MediaScanEvent` instead of creating scanner-local or UI-local media models. This keeps scanner output immediately compatible with media library and handoff contracts.

2. Treat local file URIs as the only supported scan output for this slice.

   The next useful step is file-backed local media discovery. HTTP, HLS, WebDAV, SMB, Jellyfin, provider catalog entries, and virtual BT streams need later Gateway/Network/Storage/Streaming policies before becoming scanner outputs.

3. Define scan-scope normalization before concrete traversal.

   The contract should clarify how file roots, extension filters, recursion, and exclude patterns are interpreted by contract fakes and future concrete scanners. This avoids tests depending on platform path quirks or ad hoc string matching.

4. Add typed failure and cancellation semantics.

   `MediaScanFailure` needs enough structured information for unsupported schemes, excluded entries, unreadable entries, and cancellation to be tested without parsing messages. Cancellation should be idempotent, should stop new discovery/progress events, and should define whether the watch stream completes or emits a terminal event.

5. Keep scanner behavior observable but not persistent.

   The contract can require discovered, progress, completed, failed, and cancellation semantics, but this slice must not write durable media library records. Storage-backed import can be added once scan output semantics are frozen.

6. Validate handoff compatibility at the contract boundary.

   Scanner-produced file candidates should feed the existing playback source handoff without re-parsing provider metadata or constructing playback sources directly inside scanner code. The scanner owns candidate invariants, while the handoff owns `PlaybackSource` creation.

## Risks / Trade-offs

- Scanner scope could grow into a platform crawler too early -> Keep this change limited to contracts, deterministic fakes, and checker/runtime validation.
- Storage coupling could leak into Domain media -> Defer persistence and require scan results to stay in Domain values.
- Playback coupling could leak into scanner code -> Validate candidate-to-handoff compatibility without importing player adapters into scanner-specific contracts.
- Cancellation semantics can become platform-specific -> Define caller-visible outcomes only; concrete platform cancellation mechanics remain out of scope.
- Failure taxonomy can overfit future platforms -> Start with a small enum for contract-testable categories and leave platform-specific details as messages.
