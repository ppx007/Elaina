# Phase 6: Automation Extension Core

This phase adds contract scaffolding for Celesteria architecture plan steps 26-30.

## Implemented Boundary

- RSS auto-download contracts describe feed-scoped and global policies, declarative matchers, durable history, and accepted download candidates without creating a second RSS engine.
- A Domain automation handoff translates accepted RSS candidates into engine-neutral BT task requests without letting Provider code import concrete torrent engine APIs.
- Online rule runtime contracts describe versioned manifests, CSS selector, XPath 1.0, and regex extraction targets without JavaScript, WASM, scriptlet, or arbitrary code execution.
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
