# Phase 0 Implementation Scope

Date: 2026-06-02
Sources:

- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/prd.md`
- `.trellis/tasks/06-01-bootstrap-elaina-implementation/prd.md`
- `docs/elaina-architecture-plan.md`

## Decision

Elaina's first implementation slice is the full Phase 0 / Step 1-4 foundation:

1. Layered project boundaries.
2. Local storage foundation.
3. `ProviderGateway`.
4. `CacheInvalidationBus`.

This is intentionally not a player UI slice and not a direct provider integration slice.

## Context

The early Trellis PRDs recorded a greenfield project with one durable source document: `docs/elaina-architecture-plan.md`. That architecture plan already defined the eight-layer model: UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network.

Multiple rollout cuts were possible, including starting with visible playback UI, player-core work, or provider integration. The recorded decision was to start with structural boundaries because later playback, provider, RSS, streaming, diagnostics, and network-policy work all depend on those contracts.

## Rationale

Starting with Phase 0 / Step 1-4 reduces rework risk:

- UI remains isolated from concrete playback/provider/streaming implementations.
- Provider-specific behavior enters through gateway contracts instead of direct UI dependencies.
- Cache invalidation is established before library/detail/seasonal data features expand.
- Storage shape is established before feature-specific persistence grows around it.
- Later phases can add MPV, RSS, BT streaming, diagnostics, and automation contracts without reopening the foundation.

## Explicit Non-Goals For The First Slice

- Do not build the playback page as the project starting point.
- Do not wire UI directly to MPV, VLC, Bangumi, Dandanplay, libtorrent, yuc.wiki, or raw RSS parsing.
- Do not make online source parsing a prerequisite for the core playback loop.
- Do not implement the full player roadmap in the first pass.

## Durable Product Constraints

- `Elaina` is the product name; `1017` remains the code name or abbreviation.
- yuc.wiki is treated as an RSS `FeedSource`, not a hardcoded scraper or privileged provider.
- Player, provider, RSS consumer, storage, network policy, enhancement profile, and diagnostics integrations are extension points.
- UI should expose only capabilities supported by the current environment and adapters.

## Consequence

Future implementation and review should treat Phase 0 foundation contracts as the prerequisite for later visible features. If a later change tries to start from UI or a concrete provider/player backend, it should justify why the foundation contracts are already sufficient.
