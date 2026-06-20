# Phase 0 Foundation Contracts

This document records the first implementation slice for Elaina: Phase 0 / Step 1-4 from `docs/elaina-architecture-plan.md`.

## Layer Boundaries

The foundation defines eight layers: UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network. Each layer exposes contracts and must avoid importing concrete implementations from layers it is not allowed to depend on.

The UI layer must not directly depend on MPV, VLC, Bangumi, Dandanplay, libtorrent, yuc.wiki, storage internals, or provider implementations. Future UI code should depend on Domain-facing contracts.

## Extension Points

The first extension seams are represented by Adapter, Provider, Profile, and FeatureFlag contracts. Concrete playback engines, metadata providers, RSS feeds, and enhancement profiles must plug into these seams instead of being wired into UI or Domain code.

## Storage Foundation

Storage owns SQLite metadata, blob cache, media cache, user settings, and schema migration state. Feature code must use Storage contracts rather than database or filesystem details.

Provider-facing cache behavior is governed by `ProviderGateway`; Storage may persist gateway-managed cache data, but providers must not own cache files, retry state, rate-limit state, or negative-cache records directly.

## Provider Gateway

`ProviderGateway` is the required path for provider-facing traffic. It owns request deduplication, provider rate-policy registration, retry scheduling, HTTP-cache hooks, negative-cache behavior, and normalized failure classification.

## Cache Invalidation

`CacheInvalidationBus` propagates business events such as `DanmakuPosted`, `BindingChanged`, and `ProviderAuthChanged`. Consumers react through subscriptions and their own cache handlers, not by mutating another module's internal state.
