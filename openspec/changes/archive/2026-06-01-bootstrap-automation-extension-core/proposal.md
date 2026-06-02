## Why

Celesteria has frozen local playback, ACG data, BT streaming, and advanced playback contracts, so the next roadmap slice can define online automation without weakening the offline-first playback loop. Phase 6 establishes policy-governed RSS automation, declarative online rules, manual session backfill, network policy boundaries, and local diagnostics before any concrete source implementation is introduced.

## What Changes

- Establish **Phase 6 / Step 26-30** as the automation and extension boundary.
- Define RSS auto-download policy contracts for feed-scoped filters, deduplication, and BT task handoff through existing RSS and Streaming boundaries.
- Define online rule runtime contracts for declarative CSS selector, XPath 1.0, and regex extraction rules without arbitrary code execution.
- Define WebView session backfill contracts for user-completed challenge flows and same-origin session capture.
- Define network policy boundary contracts for provider-scoped DNS, proxy, block/direct decisions, and SSRF protection.
- Define diagnostics center contracts for local event registration, structured snapshots, and read-only inspection across playback, BT, provider, RSS, rule, network, and cache flows.

## Capabilities

### New Capabilities
- `rss-auto-download-policy`: Defines rule-filtered RSS consumption, deduplication history, and engine-neutral BT task enqueue contracts.
- `online-rule-runtime`: Defines declarative online extraction rule manifests, selector evaluation, versioning, validation, and offline fallback behavior.
- `webview-session-backfill`: Defines manual challenge detection, isolated WebView completion, same-origin cookie/session capture, and provider session handoff contracts.
- `network-policy-boundary`: Defines provider-scoped network policy evaluation, DNS/proxy routing intent, SSRF protections, and platform capability reporting.
- `diagnostics-center`: Defines local diagnostics event registry, structured event snapshots, correlation, retention, export, and read-only consumer contracts.

### Modified Capabilities

None.

## Impact

- Adds Provider, Gateway, Storage, Streaming, Network, and cross-cutting diagnostics contracts for Phase 6 automation scaffolding.
- Requires all online automation to remain capability-gated and optional; core local playback and BT playback must not depend on online rules or RSS automation.
- Keeps concrete scraper implementations, JS/WASM execution, captcha auto-solving, system-level VPN/TUN control, cloud telemetry, and source-specific yuc.wiki behavior out of scope.
- Preserves existing ProviderGateway, FeedSource, Storage, BT task, and CapabilityMatrix boundaries as integration points rather than replacing them.
