# Fix Bangumi Search UTF-8 Body

## Summary
Fix Bangumi POST requests whose JSON body contains non-ASCII text, especially
home search queries such as "电视". The failure is in the concrete HTTP
transport writing a Dart string directly to `HttpClientRequest`, not in the
search UI.

## Motivation
Bangumi search and API-backed recommendation requests use JSON request bodies.
Those bodies must be encoded as UTF-8 bytes before they are written to the
socket. Direct string writes can throw before the request reaches Bangumi when
the JSON contains Chinese, Japanese, or other non-ASCII characters.

## Impact
- Affects the concrete Bangumi HTTP transport and all Bangumi POST requests.
- Preserves the existing home search UI and provider boundary.
- Does not change OAuth, detail loading, recommendations ordering, or provider
  gateway routing.
