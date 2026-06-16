## Why

Step 38 adds the first real subtitle provider implementation behind the
existing subtitle provider contracts. The current runtime already handles
provider search, retrieval, durable subtitle cache records, and parser handoff,
but concrete provider traffic is still represented by deterministic fakes.

This change adds a focused OpenSubtitles API client at the Provider layer only.
It does not add UI, login screens, subtitle selection panels, multi-provider
registries, storage migrations, playback overlays, or advanced subtitle
rendering.

## What Changes

- Add an OpenSubtitles REST API client with injectable transport for tests.
- Support subtitle search and subtitle retrieval through the existing
  `SubtitleProvider` contract.
- Route provider operations through `ProviderGateway` using deterministic
  request keys and the existing subtitle provider registration/cache policy.
- Preserve the existing subtitle-provider runtime and deterministic tests.
- Extend tests, runtime smoke checks, docs, and PowerShell checkers for the
  concrete provider.
- Keep `lib/src/ui/**`, `lib/main.dart`, `windows/**`, playback runtime,
  storage implementations, streaming, and network runtime files untouched.

## Impact

- Affected code is limited to Provider subtitle implementation, focused tests,
  tools/checkers, docs, and OpenSpec specs.
- Tests use fake transport and do not depend on live OpenSubtitles service
  availability.
- API-key storage, login, provider selection UI, and subtitle overlay work
  remain out of scope.
