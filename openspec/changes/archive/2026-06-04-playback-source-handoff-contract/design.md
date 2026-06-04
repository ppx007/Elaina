## Context

The current playback path can exercise controller commands, page intents, observable playback state, and a Flutter shell with deterministic mock behavior. The remaining gap before a useful local playback path is the handoff between a selected local media item and the Playback-layer `PlaybackSource` contract.

The repository already has Domain media contracts for local media identity and scan candidates, and Playback contracts for local file, HTTP, and HLS sources. This change defines the small bridge between those surfaces without implementing scanning, persistence, provider matching, network fetching, or native playback.

## Goals / Non-Goals

**Goals:**
- Define a deterministic Domain-facing handoff contract for preparing local media selections into `PlaybackSource` values.
- Keep local file playback as the first supported handoff path.
- Return explicit success or failure values so UI/controller callers do not infer source readiness from exceptions.
- Prove the controller can open a source produced by the handoff contract without provider, storage, streaming, network, or native dependencies.

**Non-Goals:**
- No filesystem scanner implementation, database-backed media library, or playback history persistence.
- No provider metadata matching, Bangumi binding, Dandanplay data, RSS feeds, online source parsing, or WebView session work.
- No MPV/libmpv/media-kit binding implementation, platform channels, BT streaming, HLS fetching, HTTP fetching, or gateway traffic.
- No UI page or visual work.

## Decisions

1. Keep the handoff in Domain-facing contracts.

   UI should select media through Domain media values, and Playback should receive only normalized `PlaybackSource` values. A Domain handoff contract avoids UI importing Playback adapter details while still keeping media library internals out of Playback.

2. Make local file URI handoff the first path.

   `LocalMediaIdentity` and `MediaScanCandidate` already carry a URI. The first implementation should accept file URIs and produce `LocalFilePlaybackSource`, while rejecting unsupported URI schemes with explicit failure results.

3. Use result values instead of exceptions.

   Handoff failure is expected for unsupported or incomplete media selections. A normalized result lets controller/runtime tests assert failure behavior without concrete platform errors.

4. Do not introduce storage or provider lookups.

   Existing media library contracts mention persistence and provider bindings, but this slice should only prepare already-selected local media values. Storage-backed library state and provider metadata can be layered later.

## Risks / Trade-offs

- Handoff scope may grow into scanner or repository behavior -> Keep tasks limited to value conversion and result contracts.
- Domain-to-Playback dependency direction can become blurry -> Domain may depend on Playback source contracts for the handoff output, but Playback must not import media library internals.
- HTTP/HLS temptation -> Defer remote source handoff until Network/Gateway policies are ready.
- Duplicate source models -> Reuse existing `PlaybackSource` subclasses rather than creating parallel source values.
