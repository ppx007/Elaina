# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

<!-- Patterns that must always be used -->

### Scenario: Provider Gateway Network Context

#### 1. Scope / Trigger

- Trigger: Any concrete provider API client routed through `ProviderGateway`
  and capable of outbound HTTP requests.
- Goal: Network policy, proxy routing, and diagnostics must be enforced at the
  provider boundary instead of being bypassed by direct transport calls.

#### 2. Signatures

- `ProviderGatewayRequest<T>(networkPolicyUri: Uri?, loadWithContext: ...)`
- `ProviderGatewayRequestContext(proxyUrl: String?)`
- Provider loaders that perform HTTP must accept and forward the context proxy.

#### 3. Contracts

- `networkPolicyUri` is the exact outbound URI the provider will request.
- `loadWithContext` must call the concrete client with
  `context.proxyUrl` when the transport supports proxying.
- Auth/profile requests that can change with credentials should not rely on a
  stale deduplication window after credentials change.
- Multi-hop provider flows must route each outbound URI through the gateway.
  If an API response returns a CDN/file URL, fetch that URL in a second
  `ProviderGatewayRequest` with `networkPolicyUri` set to the returned URL.

#### 4. Validation & Error Matrix

- Missing `networkPolicyUri` -> network policy is not evaluated; fix before
  shipping production provider wiring.
- Missing `loadWithContext` proxy propagation -> proxy rules appear configured
  but HTTP transport still goes direct.
- Credential-sensitive session request uses a stale dedupe cache -> user avatar
  or identity can remain from the previous token.
- Dynamic second-hop URL fetched inside the first loader -> SSRF/network policy
  cannot evaluate the returned host.

#### 5. Good/Base/Bad Cases

- Good: Bangumi API provider passes `/v0/me` as `networkPolicyUri`, uses
  `loadWithContext`, forwards `proxyUrl`, and disables session dedupe.
- Good: OpenSubtitles first requests `/api/v1/download` through the gateway,
  then fetches the returned subtitle file URL through a second gateway request.
- Base: Deterministic test providers may omit network policy fields when they
  do not perform outbound HTTP.
- Bad: Production provider executes `load: () => client.fetch()` with no URI
  and no context, because gateway policy cannot see or shape the request.
- Bad: Production provider downloads a response-provided CDN URL inside the
  same loader that requested the API metadata.

#### 6. Tests Required

- Assert `ProviderGatewayRequest.networkPolicyUri` equals the requested API URI.
- Assert proxy context reaches the recorded transport request.
- Assert credential-sensitive session requests use `networkOnly` and
  `Duration.zero` deduplication when immediate refresh is required.
- For multi-hop flows, assert the gateway sees both the API URI and the
  response-provided file/CDN URI in order.

#### 7. Wrong vs Correct

Wrong:

```dart
bangumiGatewayRequest(
  key: key,
  load: () => client.currentSession(token: token, now: now),
);
```

Correct:

```dart
bangumiGatewayRequest(
  key: key,
  load: () => client.currentSession(token: token, now: now),
  loadWithContext: (context) => client.currentSession(
    token: token,
    now: now,
    proxyUrl: context.proxyUrl,
  ),
  networkPolicyUri: client.currentSessionRequestUri(),
  deduplicationWindow: Duration.zero,
);
```

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
