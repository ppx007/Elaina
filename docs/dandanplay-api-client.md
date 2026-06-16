# Dandanplay API Client

Step 37 adds the concrete Dandanplay API client on the Provider side only. UI
and Domain code continue to depend on `DandanplayProvider`,
`DandanplayCommentProvider`, and `AcgDataController`; they must not import
transport classes or construct Dandanplay HTTP requests directly.

## Composition

App composition code may create a concrete provider like this:

```dart
final provider = DandanplayApiProvider(
  gateway: providerGateway,
  client: DandanplayApiClient(
    transport: HttpDandanplayApiTransport(),
  ),
  credentialProvider: credentialStore.currentDandanplayCredentials,
);

final runtime = DandanplayAcgRuntime(
  gateway: providerGateway,
  dandanplayProvider: provider,
  dandanplayCommentProvider: provider,
);
```

`credentialProvider` is optional. Without credentials, local media matching,
episode search, and comment retrieval remain available, while comment posting
returns a normalized `unauthenticated` result.

## Boundary Rules

- Concrete Dandanplay HTTP dispatch belongs in `lib/src/provider/dandanplay/`.
- Tests must use fake `DandanplayApiTransport`; they must not depend on live
  Dandanplay service availability.
- UI, app shell, pages, playback code, storage implementations, streaming
  engines, and network runtime policy code must not import
  `DandanplayApiClient`, `HttpDandanplayApiTransport`, or Dandanplay
  request/response payload classes.
- Provider traffic is still governed by `ProviderGateway` through deterministic
  request keys and provider registration.
