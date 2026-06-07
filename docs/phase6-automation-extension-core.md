# Phase 6: Automation Extension Core

This phase adds contract scaffolding for Celesteria architecture plan steps 26-30.

## Implemented Boundary

- RSS auto-download contracts describe feed-scoped and global policies, declarative matchers, durable history, accepted and rejected candidates, deduplication state, and enqueue outcomes without creating a second RSS engine.
- A deterministic RSS auto-download evaluator consumes `FeedItem` data already accepted by the RSS Engine, applies include/exclude matcher records, reports disabled/deduplicated/rejected/accepted outcomes, and never owns feed fetching or parsing.
- Accepted RSS candidates expose engine-neutral BT handoff read models preserving policy identity, rule identity, feed item identity, source URI, and candidate dedupe key without letting Provider code import concrete torrent engine APIs.
- RSS automation publishes cache invalidation events for policy changes, feed item evaluation, candidate acceptance/rejection, dedupe changes, and enqueue outcome recording.
- RSS auto-download capability gating is explicit: unsupported or disabled automation reports typed outcomes and does not affect RSS refresh, media-library browsing, manual BT task creation, local playback, or core startup.
- Online rule runtime contracts describe versioned manifests, CSS selector, XPath 1.0, regex extraction targets, durable manifest storage, typed validation/evaluation outcomes, normalized search/detail/episode/playable-source read models, ProviderGateway request descriptors, network-policy handoff records, and invalidation events without JavaScript, WASM, scriptlet, arbitrary code execution, concrete crawler/scraper behavior, WebView challenge handling, or mandatory startup.
- WebView session backfill contracts describe manual challenge completion, isolated same-origin session artifacts, provider session handoff, and capability reporting without automatic captcha solving.
- Network policy contracts describe provider-scoped ordered routing intent, SSRF failure kinds, and platform capability limits without promising system-wide VPN, TUN, DPI, or zero-leak routing control.
- Diagnostics center contracts describe typed local event schemas, structured snapshots, retention, redaction, and export without lifecycle control or remote telemetry.

## Non-Goals Preserved

- No concrete online source parser, crawler, scraper engine, selector implementation, or yuc.wiki-specific special case.
- No JavaScript or WASM execution for source rules.
- No automatic captcha solving, challenge bypass, shared global browser profile, or headless challenge flow.
- No concrete DNS resolver, proxy implementation, VPN service, kernel filtering, or platform network plugin.
- No diagnostics action that starts playback, changes provider state, retries feeds, modifies network policy, or enqueues BT tasks.
- No dependency that makes RSS automation or online rules mandatory for local playback, media-library use, manual BT tasks, or core playback startup.

The next change should only move beyond these contracts after checker coverage and OpenSpec validation have passed.
