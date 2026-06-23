## 1. Provider Source

- [x] 1.1 Add a Bangumi trends browser request and parser in the provider layer.
- [x] 1.2 Route trends requests through ProviderGateway with proxy and network
  policy context.
- [x] 1.3 Replace home discovery cache keys with trends-specific keys.
- [x] 1.4 Add a separate API-backed recent-popular anime discovery request with
  a 180-day air-date window.

## 2. Home Consumption

- [x] 2.1 Feed the hero carousel from the first seven official trends entries.
- [x] 2.2 Feed the waterfall from API recent-popular pagination.
- [x] 2.3 Keep duplicate suppression between hero and waterfall entries.

## 3. Validation

- [x] 3.1 Add provider tests for trends URI, parsing, failure normalization, and
  proxy propagation.
- [x] 3.2 Add provider tests for recent-popular API URI, body filters, cache key,
  and proxy propagation.
- [x] 3.3 Add UI tests for hero trends and waterfall recent-popular duplicate
  suppression.
- [x] 3.4 Run Dart analysis, targeted Flutter tests, changed-test CLI, and
  OpenSpec validation.
