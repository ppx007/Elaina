## Why

Step 37 turns the Dandanplay runtime from deterministic acceptance scaffolding
into a real provider integration. The existing contracts already cover local
media matching, search, comment retrieval, comment posting, ProviderGateway
governance, and normalized failures, but there is no concrete API client behind
those contracts.

This change adds the concrete Dandanplay API client at the Provider layer only.
UI, app shell, playback pages, danmaku overlay rendering, token persistence,
and visual controls remain outside Codex ownership for this change.

## What Changes

- Add a concrete Dandanplay API client with injectable transport for tests.
- Support local media matching, episode search, comment retrieval, and comment
  posting request/response mapping.
- Route concrete API operations through `ProviderGateway` using existing
  Dandanplay request keys, cache policies, registration, and normalized failure
  mapping.
- Preserve deterministic Dandanplay runtime fixtures and add runtime/bootstrap
  injection of concrete providers.
- Extend tests, runtime smoke checks, docs, and PowerShell checkers for
  concrete client behavior and layer-boundary hygiene.
- Keep `lib/src/ui/**`, `lib/main.dart`, `windows/**`, playback runtime,
  streaming, storage implementations, and network runtime files untouched.

## Impact

- Affected code is limited to Dandanplay Provider/Domain runtime composition,
  tests, tools/checkers, docs, and OpenSpec specs.
- Tests use fake transport and do not depend on live Dandanplay availability.
- User login, JWT persistence, app credentials, and danmaku overlay UI remain
  out of scope.
