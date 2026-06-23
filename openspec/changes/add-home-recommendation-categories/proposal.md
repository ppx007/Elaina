## Why

The lower home recommendation feed is currently a single "more recommendations"
waterfall. Users need the same waterfall to page through recent hot anime by
common Bangumi tags, while keeping the hero carousel on the official 30-day
trends source.

## What Changes

- Rename the lower recommendation section to "热门番组".
- Add a fixed category picker for common anime tags.
- Keep the waterfall layout and card behavior unchanged.
- Route category-specific pages through Bangumi v0 subject search with
  `sort=heat`, anime type filtering, a 180-day air-date window, and optional
  `meta_tags`.
- Keep ProviderGateway request keys, cache, proxy, rate policy, and normalized
  failures in the provider layer.

## Impact

- Affects home recommendation domain interfaces, Bangumi discovery requests,
  and home shell pagination state.
- Does not affect the hero carousel source, search, detail, playback, RSS,
  downloads, settings, or tracking behavior.
