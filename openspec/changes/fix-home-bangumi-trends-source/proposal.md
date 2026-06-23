## Why

The home hero currently needs Bangumi's official "注目动画 根据最近 30 日标记"
ordering from `/anime/browser/?sort=trends`. The lower "更多推荐" feed is a
different product surface: it should remain an API-backed recent-airing hot
anime waterfall, not another copy of the hero trends page.

## What Changes

- Use the official Bangumi anime trends browser source only for the home hero.
- Use Bangumi v0 subject search with `sort=heat` and a 180-day `air_date`
  window for the lower more-recommendations waterfall.
- Keep both sources inside the Bangumi provider boundary so UI code never
  parses Bangumi HTML or calls Bangumi endpoints directly.
- Continue routing provider traffic through ProviderGateway, including network
  policy URI, proxy context, cache key, and normalized failures.
- Keep duplicate suppression so the API waterfall does not repeat hero subjects
  when the two sources overlap.

## Impact

- Affects Bangumi discovery provider requests and cache keys.
- Affects home page recommendation data ordering.
- Does not change search, detail, login, local media, playback, RSS, or download
  flows.
