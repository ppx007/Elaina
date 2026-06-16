# Bangumi API Client

Step 36 adds the concrete Bangumi API client on the Provider side only. UI and
Domain code continue to depend on `BangumiProvider`, `BangumiAuthProvider`, and
`AcgDataController`; they must not import transport classes or construct HTTP
requests directly.

## Composition

App composition code may create a concrete provider like this:

```dart
final provider = BangumiApiProvider(
  gateway: providerGateway,
  client: BangumiApiClient(
    transport: HttpBangumiApiTransport(),
  ),
  accessTokenProvider: tokenStore.currentBangumiAccessToken,
);

final runtime = BangumiAcgRuntime(
  gateway: providerGateway,
  bangumiProvider: provider,
  bangumiAuthProvider: provider,
);
```

`accessTokenProvider` is optional. Without a token, metadata lookup and search
remain available, while session and progress sync return normalized
`unauthenticated` results.

## Boundary Rules

- Concrete Bangumi HTTP dispatch belongs in `lib/src/provider/bangumi/`.
- Tests must use fake `BangumiApiTransport`; they must not depend on live
  Bangumi service availability.
- UI, app shell, pages, playback code, storage implementations, streaming
  engines, and network runtime policy code must not import `BangumiApiClient`,
  `HttpBangumiApiTransport`, or Bangumi request/response payload classes.
- Provider traffic is still governed by `ProviderGateway` through deterministic
  request keys and provider registration.
