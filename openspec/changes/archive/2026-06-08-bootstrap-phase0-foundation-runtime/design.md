## Context

The repository now contains archived contract scaffolding for Celesteria architecture steps 1-30, including the Phase 6 extension freeze. The architecture plan explicitly states that formal implementation should begin with Phase 0 / Step 1-4: layered architecture, local storage, ProviderGateway, and CacheInvalidationBus. Those contracts exist today, but there is not yet a single executable foundation runtime bootstrap that composes them in the prescribed order.

This change converts the first implementation slice from scattered deterministic contracts into a deliberate foundation runtime composition. The implementation must remain contract-first and local-first: it can wire deterministic stores, provider registrations, request descriptors, and invalidation bus lifecycle, but it must not introduce concrete platform adapters, Flutter UI, network clients, database drivers, MPV/VLC/libtorrent integrations, online source execution, WebView automation, or background schedulers.

## Goals / Non-Goals

**Goals:**

- Provide a Phase 0 foundation runtime/bootstrap surface that composes only Step 1-4 capabilities.
- Make layer boundaries executable through a manifest/checker so future modules cannot silently bypass the 8-layer architecture.
- Provide a deterministic `StorageFoundation` implementation that exposes existing local store contracts through one bootstrap dependency.
- Provide a deterministic ProviderGateway bootstrap that preserves provider registration, request keys, cache policy, storage access, typed failures, and de-duplication boundaries without concrete network dispatch.
- Provide lifecycle-managed CacheInvalidationBus bootstrap wiring for Step 1-4 services.
- Add tests and runtime checks proving the foundation runtime can be constructed, used, and disposed without crossing layer boundaries.

**Non-Goals:**

- No Flutter shell, pages, widgets, or UI actions.
- No concrete MPV, VLC, libtorrent, HTTP, DNS, proxy, SQLite, file-system blob, WebView, or platform service adapters.
- No online rule execution, scraper/crawler behavior, automatic captcha solving, or yuc.wiki-specific behavior.
- No playback lifecycle control, BT enqueue/control, provider mutation outside ProviderGateway registration, or network-policy mutation.
- No migration from deterministic in-memory scaffolding to durable production storage.

## Decisions

1. **Bootstrap in `foundation`, not UI or app shell.**
   - Decision: Add the composition surface under `lib/src/foundation/` so it can be imported by tests and later app-shell wiring without giving UI direct access to concrete adapters.
   - Alternative rejected: Create Flutter app initialization now. That would violate the architecture plan by starting from UI before Step 1-4 foundations are frozen.

2. **Use deterministic in-memory implementations for Phase 0 runtime wiring.**
   - Decision: Compose existing deterministic stores and bus implementations behind `StorageFoundation`, `ProviderGateway`, and CacheInvalidationBus interfaces.
   - Alternative rejected: Add SQLite/blob-cache/HTTP clients now. Those are platform/concrete adapter concerns and would make the foundation slice too broad.

3. **Keep ProviderGateway bootstrap descriptor-driven.**
   - Decision: ProviderGateway bootstrap may register providers, preserve request/cache metadata, enforce de-duplication boundaries, and return typed failures/successes from supplied loaders, but it must not own HTTP transport.
   - Alternative rejected: Add a network dispatcher to ProviderGateway. That would couple Gateway to Network implementation before network adapters are selected.

4. **Treat CacheInvalidationBus as lifecycle-managed infrastructure.**
   - Decision: The runtime bootstrap owns a bus instance and exposes explicit disposal/close behavior so tests can prove no dangling stream controllers remain.
   - Alternative rejected: Global singleton event bus. That would hide lifecycle and make future tests leak state.

5. **Make layer rules executable.**
   - Decision: Extend checker/runtime validation to assert that foundation runtime bootstrap does not import UI, playback adapters, provider implementations, streaming engines, or concrete network/platform adapters.
   - Alternative rejected: Rely on documentation only. The repository already uses boundary checkers; this slice should preserve that enforcement style.

## Risks / Trade-offs

- **Risk:** A bootstrap surface can become a service locator dumping ground. → **Mitigation:** Limit the public surface to Step 1-4 dependencies and tests; require later capabilities to extend through explicit OpenSpec changes.
- **Risk:** Deterministic implementations may be mistaken for production adapters. → **Mitigation:** Name deterministic scaffolding clearly and document that concrete platform/database/network adapters remain out of scope.
- **Risk:** ProviderGateway behavior can accidentally become network transport. → **Mitigation:** Tests and checkers must reject HTTP client, crawler, DNS/proxy, and platform transport terms in the bootstrap slice.
- **Risk:** Layer boundary checking may be incomplete. → **Mitigation:** Keep checks conservative and focused on forbidden dependencies; refine after real app-shell wiring exists.

## Migration Plan

1. Add foundation runtime/bootstrap contracts and deterministic implementations.
2. Wire the public Dart barrel only for contract-safe foundation surfaces.
3. Add focused tests for bootstrap construction, storage access, provider gateway request behavior, invalidation events, and disposal.
4. Extend runtime and boundary checkers.
5. Run OpenSpec validation, Dart analysis, focused tests, and existing project checkers.

Rollback is straightforward: revert the bootstrap files, tests, checker updates, and spec deltas. No data migration is introduced.

## Open Questions

- Should the later production app shell instantiate this bootstrap directly, or should it wrap it in a platform-specific composition root? This can wait until Flutter shell work resumes.
- Should durable storage adapters be proposed as one follow-up change or split by SQLite/blob/media/settings domains? This should be decided after the deterministic foundation runtime is in place.
