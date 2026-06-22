## Why

The RSS page currently exposes only a per-feed auto-download toggle. That is
not enough for real subscription automation: users need feed-scoped include
and exclude rules, previewable matches, and deterministic handoff into the
download runtime without putting torrent or policy logic in the UI.

## What Changes

- Add feed-scoped RSS auto-download rule management to `RssEngineRuntime`.
- Allow the RSS page to create, edit, delete, enable, disable, and preview
  rules for the selected feed.
- Execute enabled rules after successful RSS refresh and enqueue accepted
  candidates through an RSS-to-download adapter.
- Resolve remote `.torrent` URLs to local file URIs before calling the
  download runtime; magnet links continue to enqueue directly.
- Keep UI out of storage, policy evaluator internals, concrete BT engines, and
  concrete HTTP torrent fetching.

## Impact

- Affects RSS runtime, RSS page UI, RSS auto-download policy storage mapping,
  app composition wiring, and focused RSS/download tests.
- Does not add a global rule center, Bangumi matching, RSS-to-tracking
  automation, or RSS page ownership of concrete download engines.
