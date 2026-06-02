# Phase 0 Storage Schema Boundary

This file defines the initial SQLite metadata boundary. It is intentionally a contract, not a generated migration, because the Dart/Flutter toolchain is not available in this workspace yet.

## Tables

| Table | Purpose | Initial owner |
|---|---|---|
| `schema_migrations` | Records applied schema versions and migration timestamps. | Storage |
| `playback_records` | Future playback position, completion, and resume metadata. | Domain via Storage |
| `rss_entries` | Future normalized RSS/Atom entries and deduplication keys. | Provider/RSS via Gateway + Storage |
| `provider_state` | Provider auth/session/binding state that must survive restart. | Provider via Gateway + Storage |
| `cache_entries` | Gateway-owned HTTP, semantic, and negative-cache metadata. | Gateway via Storage |
| `diagnostic_snapshots` | Future diagnostics snapshots for playback, provider, cache, and A/V sync state. | Diagnostics via Storage |

## Migration Rules

1. Every schema change increments `SchemaVersion`.
2. Migrations are ordered and must run before feature code reads the upgraded schema.
3. Provider-facing cache tables are owned by `ProviderGateway` policy, even when persisted by Storage.
