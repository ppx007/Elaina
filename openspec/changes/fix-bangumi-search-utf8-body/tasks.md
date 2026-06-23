## 1. Transport

- [x] 1.1 Encode Bangumi JSON request bodies as UTF-8 bytes before writing.
- [x] 1.2 Declare JSON request bodies as `application/json; charset=utf-8`.
- [x] 1.3 Preserve ProviderGateway network policy and proxy routing.

## 2. Search Behavior

- [x] 2.1 Keep home search on `POST /v0/search/subjects`.
- [x] 2.2 Preserve anime subject filtering and provider-routed search.
- [x] 2.3 Verify Chinese search queries reach the provider as valid JSON.

## 3. Validation

- [x] 3.1 Add transport regression coverage for UTF-8 body bytes.
- [x] 3.2 Add provider coverage for Chinese Bangumi search request bodies.
- [x] 3.3 Add widget coverage for Chinese home search flow.
- [x] 3.4 Run Dart analysis, targeted Flutter tests, Fast gate, and OpenSpec
  validation.
