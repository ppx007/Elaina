## Why

The home page currently uses Bangumi v0 subject search with `sort=heat` and an
`air_date` filter. That returns recently aired hot anime, not the official
Bangumi "注目动画 根据最近 30 日标记" list shown at `/anime/browser/?sort=trends`.

## What Changes

- Use the official Bangumi anime trends browser source for the home hero and
  more-recommendations feed.
- Keep the source inside the Bangumi provider boundary so UI code never parses
  Bangumi HTML or calls Bangumi endpoints directly.
- Continue routing provider traffic through ProviderGateway, including network
  policy URI, proxy context, cache key, and normalized failures.
- Stop using the old six-month recent-popular API search path for the home
  recommendation waterfall.

## Impact

- Affects Bangumi discovery provider requests and cache keys.
- Affects home page recommendation data ordering.
- Does not change search, detail, login, local media, playback, RSS, or download
  flows.
