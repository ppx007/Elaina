## Why

Step 36 moves Bangumi from deterministic runtime bootstrap toward a real
provider integration. The existing runtime validates gateway governance,
request keys, optional auth, and normalized failures, but it does not yet have
a concrete client that can issue Bangumi HTTP API requests behind the provider
boundary.

This change adds that concrete client without implementing UI login, detail
pages, playback surfaces, or app-shell wiring. The client remains a Provider
layer implementation detail and Domain/UI continue to consume the existing
Bangumi contracts.

## What Changes

- Add a concrete Bangumi API client with injectable transport for tests.
- Support subject lookup, subject search, episode lookup, current session, and
  progress sync request mapping.
- Route all concrete client operations through `ProviderGateway` using the
  existing Bangumi request keys, cache policies, registration, and normalized
  failure mapping.
- Keep deterministic Bangumi runtime fixtures available for offline tests and
  existing scaffold usage.
- Extend tests and checkers for request construction, response mapping,
  authentication behavior, gateway governance, and layer-boundary hygiene.
- Keep `lib/src/ui/**`, `lib/main.dart`, `windows/**`, playback, streaming,
  storage, and network runtime implementation files untouched.

## Impact

- Affected code is limited to Bangumi Provider/Domain runtime composition,
  tests, tools/checkers, docs, and OpenSpec specs.
- No live network tests are required; tests use a fake transport.
- OAuth UI, token persistence, refresh-token storage, and progress sync UX
  remain out of scope for this change.
