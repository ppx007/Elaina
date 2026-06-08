## Context

Celesteria already models online rule source retrieval and provider traffic through ProviderGateway and network-policy boundaries. Phase 6 Step 28 adds the missing manual recovery path for providers that present a challenge, where a user completes the challenge in an isolated WebView and same-origin session artifacts are normalized back into provider session contracts.

The architecture plan is explicit that captcha automation is forbidden: only manual completion followed by same-origin session backfill is allowed. This change therefore deepens contracts without adding a concrete WebView UI, platform browser adapter, captcha solver, crawler, or global cookie bridge.

## Goals / Non-Goals

**Goals:**

- Define a manual challenge lifecycle from detection to isolated completion, normalized artifact capture, backfill attempt, retry descriptor, expiry, and revocation.
- Keep provider session artifacts scoped by provider identity and origin, with no global browser state access.
- Persist challenge/backfill state through Storage contracts so flows can survive restart and support diagnostics later.
- Ensure retried provider traffic still passes through ProviderGateway and network policy enforcement.
- Expose capability limits for platforms without isolated WebView capture.

**Non-Goals:**

- No automatic captcha solving, challenge bypass, credential guessing, bot completion, or headless browser automation.
- No concrete Flutter WebView screen, WebView plugin binding, native browser adapter, or UI flow.
- No JavaScript execution engine, scraper automation, online rule crawler, or page evaluation behavior.
- No DNS resolver, proxy, VPN, or network transport implementation.
- No diagnostics UI or user notification implementation.

## Decisions

1. **Manual-only state machine over automated challenge handling.**
   The contracts model `required`, `opened`, `completed`, `captured`, `backfilled`, `expired`, `revoked`, and `failed` states. This makes the legal path explicit while keeping forbidden automation out of the type surface.

2. **Provider/origin isolation is part of the artifact identity.**
   Captured cookies and optional provider tokens include provider id, origin, domain, path, expiry, secure flag, SameSite state, capture time, and approval metadata. A same-origin check is required before artifacts can be attached to a retry descriptor.

3. **ProviderGateway owns retries after backfill.**
   Backfill produces declarative retry/session descriptors. Providers do not receive direct database handles, WebView handles, global browser cookies, or transport bypass hooks.

4. **Network policy checks both challenge origin and retried request.**
   Challenge navigation and backfilled retries must remain provider-scoped traffic. Network policy can block disallowed schemes, private/loopback/link-local destinations, unsafe redirects, and provider-prohibited hosts before session artifacts are used.

5. **Storage and invalidation are explicit but implementation-neutral.**
   The storage layer persists normalized read models and outcomes; CacheInvalidationBus reports lifecycle changes. Neither contract requires a concrete database schema, WebView package, diagnostics surface, or online rule runtime startup.

## Risks / Trade-offs

- **Risk: Contract appears to promise captcha solving.** → Mitigation: requirements and types name manual completion only and explicitly reject automation/bypass behavior.
- **Risk: Cookie leakage across providers or origins.** → Mitigation: provider id, origin, domain/path scope, expiry, and same-origin checks are normative requirements.
- **Risk: Providers bypass gateway after backfill.** → Mitigation: backfill returns retry descriptors governed by ProviderGateway and network policy, not raw transport access.
- **Risk: Platform WebView support differs.** → Mitigation: capability contracts report unsupported isolated capture without breaking provider flows that do not need challenge recovery.
- **Risk: Expired or revoked artifacts are reused.** → Mitigation: storage contracts include expiry/revocation metadata and retry descriptors must reject inactive artifacts.
