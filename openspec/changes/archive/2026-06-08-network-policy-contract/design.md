## Context

Elaina routes external capabilities through ProviderGateway, and recent Phase 6 slices added online rule runtime and manual WebView challenge backfill. These flows share the same risk boundary: provider-scoped traffic can target unsafe schemes, private or loopback networks, provider-prohibited hosts, or domains that require declarative DNS/proxy intent. The architecture plan requires per-domain DNS, DoH/DoT, SSRF protection, and proxy support, but also states that DNS policy is provider/domain configured and defaults to system DNS.

This design deepens the contracts without implementing a resolver, proxy, VPN, TUN, kernel filter, DPI system, or platform network plugin.

## Goals / Non-Goals

**Goals:**

- Define provider-scoped network policy profiles and ordered rules.
- Represent DNS resolver intent, DoH/DoT resolver intent, proxy tag intent, direct routing intent, block decisions, fallback behavior, and audit metadata.
- Normalize SSRF/security failure kinds for disallowed schemes, loopback, link-local, private network ranges, unsafe redirects, and blocked hosts.
- Persist network policy state and evaluation snapshots through Storage contracts.
- Expose deterministic evaluator scaffolding and ProviderGateway handoff descriptors.
- Publish cache invalidation events for policy/profile changes, provider assignment changes, evaluation outcomes, and capability changes.

**Non-Goals:**

- No concrete DNS lookup, DoH/DoT HTTP client, resolver cache, proxy server, PAC file parser, VPN service, TUN interface, kernel filter, DPI, packet capture, or zero-leak routing guarantee.
- No system-wide routing control; policy applies only to Elaina-managed provider traffic.
- No UI, settings screen, diagnostics UI, or platform plugin implementation.
- No bypass of ProviderGateway, online-rule runtime, RSS engine, or WebView session boundaries.

## Decisions

1. **Policy rules are declarative intent, not transport execution.**
   Rule outcomes describe `systemDns`, `configuredDns`, `doh`, `dot`, `proxyTag`, `direct`, and `block` intent. Concrete networking adapters can interpret these later, but Provider and UI code only see contract decisions.

2. **Provider scope is required on every request and policy.**
   Per-domain rules are evaluated inside a provider scope so one provider's proxy/DNS preference cannot leak into another provider, RSS feed, online rule source, or WebView challenge flow.

3. **SSRF checks are normalized before dispatch.**
   The evaluator reports typed failures for unsafe schemes, loopback, link-local, private networks, unsafe redirects, and blocked hosts. This keeps higher layers independent of platform resolver details.

4. **Capability limits are explicit.**
   Platforms that cannot enforce configured DNS, DoH, DoT, proxy intent, redirect validation, or background networking report unsupported capability state and fall back to system DNS unless the policy requires a block.

5. **Storage and invalidation are first-class contracts.**
   Network policy profiles, rules, assignments, evaluations, and capability state are durable records. Mutations publish events rather than creating direct Gateway/Network/Provider coupling.

## Risks / Trade-offs

- **Risk: Users infer system-wide VPN-like routing.** → Mitigation: requirements and checkers forbid VPN/TUN/kernel/DPI/zero-leak promises and require provider-scoped wording.
- **Risk: Declarative DNS/proxy intent is mistaken for a working resolver.** → Mitigation: contracts use intent descriptors and capability state only; concrete resolver/proxy implementations remain future adapters.
- **Risk: SSRF checks require resolved IPs in real implementations.** → Mitigation: contract supports normalized failure kinds and evaluation snapshots without requiring a resolver in this slice.
- **Risk: Provider traffic bypasses policy.** → Mitigation: ProviderGateway requirements require network policy handoff before dispatch for provider-facing requests.
- **Risk: Platform differences break flows.** → Mitigation: capability contracts allow graceful fallback or normalized blocking without breaking provider-independent flows.
