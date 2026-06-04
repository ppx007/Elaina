## Context

Step 16 defines the RSS Engine foundation: `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, and deduplication for RSS/Atom. Bootstrap contracts already exist in `lib/src/provider/rss/feed_contracts.dart`, but feed state has no Storage ownership and there is no Domain-facing orchestration contract that ties fetch, parser, deduplication, persistence, and update emission together. Step 17 YucWiki seasonal indexing depends on this engine but must remain a normal `FeedSource` consumer, not a special scraper path.

## Goals / Non-Goals

**Goals:**
- Define Storage-layer feed source, item, cursor, and deduplication records.
- Define Domain RSS orchestration that composes provider feed fetchers, parsers, schedulers, deduplicators, and Storage contracts.
- Preserve `ProviderGateway` governance for feed network traffic, including cache validators and normalized failure semantics.
- Keep RSS and Atom extensible through existing `FeedSource`, `FeedParser`, and `FeedConsumer`-style boundaries.

**Non-Goals:**
- No concrete HTTP client, XML parser implementation, or network transport.
- No YucWiki seasonal normalization or Bangumi match queue behavior.
- No RSS auto-download rules, torrent enqueueing, or BT integration.
- No RSS page UI, subscription management UI, or background service behavior.

## Decisions

1. **Durable feed state belongs to Storage, not Provider.**
   Provider RSS contracts can fetch and parse feed data, but feed source registration, fetch cursor metadata, seen dedupe keys, and persisted feed items should be Storage responsibilities so RSS providers do not create ad hoc databases or cache files.

2. **Domain orchestrates the feed refresh pipeline.**
   A Domain RSS engine contract should coordinate `FeedScheduler`, `FeedFetcher`, `FeedParser`, `FeedDeduplicator`, and Storage stores. This keeps UI and future seasonal consumers away from concrete provider implementations.

3. **Conditional fetch metadata is part of the contract.**
   `FeedFetchRequest` already has `etag` and `lastModified`; the engine should persist and replay those values through Storage cursor records so future fetchers can use HTTP cache validators without owning persistence.

4. **Deduplication keys are provider-neutral.**
   RSS `guid`, Atom `id`, and fallback composite keys should normalize into `FeedDedupeKey`. Storage should persist accepted keys per source so repeated refreshes return only new feed items.

5. **YucWiki remains out of this slice.**
   The engine must be able to refresh a `FeedSource`, but source-specific seasonal normalization remains Step 17 and should not leak into Step 16 contracts.

## Risks / Trade-offs

- [Feed schema too concrete] -> Use typed records and cursor contracts, but avoid SQLite table layout or serialized XML details.
- [RSS implementation drifts into transport] -> Keep concrete HTTP/XML behavior behind `FeedFetcher` and `FeedParser` interfaces.
- [Dedup false positives] -> Preserve the normalized dedupe key and original source/item identifiers so future consumers can audit decisions.
- [Scheduler complexity expands too early] -> Define due-source and cursor contracts now; leave background execution and OS scheduling to later platform work.

## Migration Plan

1. Add feed persistence contracts to Storage foundation.
2. Add Domain RSS engine orchestration contracts and deterministic test doubles.
3. Add tests for fetch cursor reuse, deduplication, persistence, update emission, and gateway failure propagation.
4. Update runtime/checker validation and sync specs on archive.

## Open Questions

- Should feed item content store raw XML fragments, normalized summaries only, or both?
- Should failed refresh history live in the RSS engine store or a later diagnostics store?
- Should scheduler jitter/backoff be modeled in this slice or deferred to background execution work?
