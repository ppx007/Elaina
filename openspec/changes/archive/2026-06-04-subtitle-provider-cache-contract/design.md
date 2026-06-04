## Context

Step 15 calls for SubtitleProvider support covering external providers, local subtitles, and cache behavior. Current source already defines `SubtitleProvider`, `SubtitleSearchQuery`, `SubtitleProviderCandidate`, `RetrievedSubtitleFile`, parser/source contracts, local subtitle scanning, and a small Domain bridge. The missing contract is the cache/orchestration layer that makes those pieces usable together without introducing a concrete network provider.

## Goals / Non-Goals

**Goals:**
- Define Storage-layer cache records for subtitle search results and retrieved subtitle content.
- Define a Domain subtitle discovery contract that merges local scanner and provider-backed search paths.
- Define retrieval-to-parser handoff semantics, including encoding hint propagation.
- Keep provider traffic behind existing `SubtitleProvider` and `ProviderGateway` contracts.

**Non-Goals:**
- No concrete OpenSubtitles or other provider implementation.
- No HTTP client, native subtitle extraction, or platform channel behavior.
- No UI rendering or advanced caption layout.
- No RSS Engine, seasonal indexer, or auto-download behavior.

## Decisions

1. **Subtitle cache belongs to Storage, not Provider.**
   Provider contracts declare cache policy and return candidates/files, but durable search/content cache records belong under `StorageFoundation` so provider implementations do not create ad hoc persistence paths.

2. **Domain orchestration composes existing contracts.**
   A Domain subtitle discovery contract should accept local media/subtitle requests, call a local scanner when available, call `SubtitleProvider` contracts for provider-backed search, and convert retrieved files into `SubtitleParseRequest` values through the existing bridge.

3. **Provider traffic remains ProviderGateway-mediated.**
   The orchestration contract must not introduce direct HTTP or source-specific API calls. Concrete providers remain responsible for routing through `ProviderGateway` by implementing `GatewayBoundProvider`.

4. **Cache keys must be stable and provider-neutral.**
   Search caches should be keyed by normalized query inputs and provider id. Retrieved content caches should be keyed by provider id plus provider candidate reference/id, with TTL taken from `SubtitleProviderCachePolicy`.

5. **Parser handoff preserves encoding hints.**
   Retrieved subtitle files already carry `encodingHint`; this change should require that hint to flow into `SubtitleParseRequest` so future parsers can handle non-UTF-8 subtitle files without guessing.

## Risks / Trade-offs

- [Cache shape too concrete] -> Use typed records and TTL contracts, but avoid SQLite schema or serialized JSON layout.
- [Orchestration grows into provider implementation] -> Keep the contract provider-neutral and do not add OpenSubtitles-specific behavior.
- [Local scanner and provider results conflict] -> Return both through explicit result types; do not silently prefer provider results over local subtitles.
- [Encoding edge cases] -> Preserve hints in the contract now, while actual encoding detection/conversion remains a later parser implementation concern.

## Migration Plan

1. Add subtitle cache capability and delta specs.
2. Add Storage foundation subtitle cache responsibilities.
3. Add Domain discovery orchestration contracts and deterministic test doubles.
4. Add contract tests and checker/runtime validation.

## Open Questions

- Should cached retrieved content store raw text only, or also retain source URI/cached URI metadata?
- Should Domain discovery expose one combined result list or separate local/provider result buckets?
- Should negative-cache records be part of this slice or remain ProviderGateway-owned only?
