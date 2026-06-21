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

The default concrete client User-Agent follows Bangumi's published guidance for
non-browser API clients:

```text
ppx007/Elaina/0.1.0 (Windows; Flutter) (https://github.com/ppx007/Elaina)
```

Do not replace it with a generic library default. OAuth application secrets,
access tokens, and refresh tokens must remain in local user configuration or a
secure credential store, never in source-controlled code or docs.

## Optional Mirror

Elaina defaults to the official Bangumi API and image URLs. Users may enable a
self-hosted mirror from Settings by providing both:

- an API mirror base URL, for example `https://bangumi.example.com/api`
- an image mirror base URL, for example `https://bangumi.example.com/image`

The recommended deployment template lives in `deploy/bangumi-worker/`. The
mirror setting changes the effective provider request URL and rewrites Bangumi
image URLs; it does not mirror the OAuth/token acquisition page.

## Boundary Rules

- Concrete Bangumi HTTP dispatch belongs in `lib/src/provider/bangumi/`.
- Desktop integration defaults to official API and OAuth endpoints. Optional
  API/image mirrors must be self-hosted and configured by the user. Bangumi
  garage components are site-local JavaScript/CSS enhancements and are not an
  Elaina integration surface.
- Tests must use fake `BangumiApiTransport`; they must not depend on live
  Bangumi service availability.
- UI, app shell, pages, playback code, storage implementations, streaming
  engines, and network runtime policy code must not import `BangumiApiClient`,
  `HttpBangumiApiTransport`, or Bangumi request/response payload classes.
- Provider traffic is still governed by `ProviderGateway` through deterministic
  request keys and provider registration.
