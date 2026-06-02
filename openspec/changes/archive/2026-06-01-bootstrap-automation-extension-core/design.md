## Context

Phase 5 archived advanced playback contracts. The architecture plan defines Phase 6 as Step 26 RSS auto-download, Step 27 online rule sources, Step 28 WebView challenge/session backfill, Step 29 DNS/network policy, and Step 30 diagnostics center.

This change defines automation contracts before concrete online providers are implemented. The goal is to make online automation useful while keeping the player offline-first, source-neutral, policy-governed, and capability-scoped.

## Goals / Non-Goals

**Goals:**
- Define RSS auto-download policies that reuse RSS engine deduplication and enqueue BT tasks through engine-neutral Streaming contracts.
- Define a declarative online rule runtime for CSS selector, XPath 1.0, and regex extraction manifests.
- Define manual WebView session backfill for challenge completion and same-origin session capture.
- Define provider-scoped network policy boundaries for DNS/proxy/block/direct intent, SSRF protection, and platform capability limits.
- Define a local diagnostics center that records typed events and snapshots without becoming a remote telemetry system or lifecycle controller.

**Non-Goals:**
- Implementing concrete online source parsers, yuc.wiki special handling, or a full scraper framework.
- Implementing JS/WASM execution, arbitrary scriptlets, adblock-style procedural filtering, or AI semantic extraction.
- Solving captchas automatically, bypassing challenges, or making WebView mandatory for every provider.
- Implementing system-wide VPN/TUN routing, kernel packet filtering, DPI, or zero-leak DNS guarantees.
- Requiring RSS automation or online rules for local playback, BT playback, or media-library operation.

## Decisions

### 1. RSS automation is a policy consumer, not a new feed engine

RSS auto-download will consume existing `FeedSource`, fetcher/parser/scheduler, dedupe, and Storage contracts. Its policy result can enqueue a BT task through Streaming contracts, but it will not parse feeds independently or call a concrete torrent engine.

**Alternative considered:** define a dedicated auto-download feed pipeline. Rejected because it would duplicate RSS foundation behavior and create a second path around ProviderGateway and feed deduplication.

### 2. Online rules are declarative manifests

Online rules will be versioned manifests containing source metadata, selectors, XPath 1.0 expressions, regex extractors, update metadata, and validation state. The runtime evaluates declared extraction steps and reports unsupported operations instead of executing arbitrary source code.

**Alternative considered:** allow JS/WASM rule execution in Phase 6. Rejected because executable source logic would expand the security and portability surface before the policy, diagnostics, and validation boundaries exist.

### 3. WebView backfill is manual and same-origin scoped

Challenge handling will surface a manual completion requirement, open an isolated WebView session, and capture only same-origin session artifacts needed by the provider session boundary after the user completes the challenge.

**Alternative considered:** automate challenge completion or share a global browser profile. Rejected because it violates the manual-only captcha rule and increases session leakage risk across providers.

### 4. Network policy is provider-scoped intent

Network policy will describe ordered rules for provider traffic, including domain matching, DNS/proxy/direct/block intent, fallback behavior, and SSRF protections. Enforcement remains app-level and platform-capability-scoped.

**Alternative considered:** promise system-wide DNS/proxy enforcement. Rejected because platform limits differ substantially and Celesteria should not claim VPN/TUN behavior in a provider policy contract.

### 5. Diagnostics center is read-only local observability

Diagnostics will register typed local event schemas and collect structured snapshots with correlation IDs and retention policy. It can expose local export contracts, but it does not upload telemetry or own module lifecycle controls.

**Alternative considered:** build a full monitoring/export system. Rejected because Phase 6 needs local troubleshooting boundaries, not a backend observability product.

## Risks / Trade-offs

- **[Risk] Online rule runtime becomes an executable scraping platform** -> **Mitigation:** restrict Phase 6 to declarative selector and regex manifests with validation and unsupported-operation reporting.
- **[Risk] RSS auto-download bypasses BT and RSS boundaries** -> **Mitigation:** require FeedSource consumption, stable dedupe history, ProviderGateway fetch governance, and engine-neutral BT task enqueue contracts.
- **[Risk] Session artifacts leak across providers** -> **Mitigation:** require isolated WebView sessions, same-origin capture, scoped storage, and explicit provider session handoff.
- **[Risk] Network policy overpromises platform control** -> **Mitigation:** model policy as app-level provider intent with capability reporting and safe fallback to system DNS by default.
- **[Risk] Diagnostics becomes a control plane** -> **Mitigation:** keep diagnostics read-only with event registration, snapshots, filtering, retention, and export contracts only.

## Migration Plan

This is a greenfield continuation from Phase 5:

1. Add RSS auto-download policy contracts and BT task handoff requirements.
2. Add declarative online rule manifest and evaluation contracts.
3. Add manual WebView session backfill contracts.
4. Add provider-scoped network policy contracts.
5. Add diagnostics center event registry and snapshot contracts.
6. Add Phase 6 documentation and checker coverage that verifies boundary isolation and anti-scope exclusions.

## Open Questions

- Which concrete selector libraries should the first Dart implementation use for CSS and XPath evaluation?
- What is the first persisted schema shape for RSS auto-download history and diagnostics snapshots?
- Which platforms should expose provider-scoped proxy policy first, given iOS and desktop capability differences?
