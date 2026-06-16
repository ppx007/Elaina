# OpenSubtitles Provider

Step 38 adds a concrete OpenSubtitles provider behind the existing subtitle
contracts. It is Provider-layer code only: UI, playback surfaces, file pickers,
subtitle selection panels, and overlay rendering remain out of scope.

## Composition

App composition code can create the provider with an existing gateway and
subtitle cache:

```dart
final provider = OpenSubtitlesProvider(
  gateway: providerGateway,
  client: OpenSubtitlesApiClient(
    transport: HttpOpenSubtitlesApiTransport(),
  ),
  config: const OpenSubtitlesApiConfig(
    apiKey: 'configured-api-key',
  ),
);

final bootstrap = SubtitleProviderBootstrap(
  provider: provider,
  cache: subtitleCacheStore,
);
```

Tests and smoke checks should inject `OpenSubtitlesApiTransport` fakes instead
of calling the live OpenSubtitles service.

## Boundary

- UI must consume Domain/Playback subtitle contracts, not
  `OpenSubtitlesProvider`, `OpenSubtitlesApiClient`, or
  `HttpOpenSubtitlesApiTransport`.
- Provider traffic must flow through `ProviderGateway`.
- Search returns existing `SubtitleProviderCandidate` values.
- Retrieval returns existing `RetrievedSubtitleFile` values for parser handoff.
- API keys are configuration input for app composition; this change does not
  add credential storage, login UI, account flows, or provider selection UI.
