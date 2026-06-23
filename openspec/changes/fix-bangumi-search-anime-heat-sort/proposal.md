# Fix Bangumi Search Anime Heat Sort

## Summary
Change home Bangumi search suggestions to request anime subjects only and sort
them by Bangumi heat, which is the closest API-backed ordering to collection
count/popularity. The UI continues to use the existing home search provider and
does not add client-side Bangumi filtering.

## Motivation
`sort=match` can over-prioritize literal title matches and surface low-value
subjects for short queries. Home search needs useful anime suggestions first,
not broad catalog matches such as books or magazines.

## Impact
- Home search remains `POST /v0/search/subjects`.
- Home search request bodies use `sort=heat`.
- Home search request bodies keep `filter.type=[2]` so results are limited to
  anime.
- ProviderGateway routing, proxy propagation, cache keys, and UTF-8 body
  encoding remain unchanged.
