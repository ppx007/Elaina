## Why

The current RSS page is a shallow two-column view with broken Chinese text and
only partial use of the RSS runtime snapshot. It does not expose source
removal, refresh outcomes, cursor state, item filtering, or persisted parsed
items clearly enough to be a usable subscription management surface.

## What Changes

- Redesign the RSS page as a dense subscription management workspace with a
  toolbar, source list, status summary, item stream, search, and source
  filtering.
- Surface existing runtime data: registered sources, auto-download activation,
  latest refresh results, cursor timestamps, dedupe counts, and accepted feed
  items.
- Add user-facing actions for adding, refreshing, enabling auto-download, and
  removing subscriptions with confirmation.
- Fix all visible RSS page Chinese copy to valid UTF-8.
- Make `RssEngineRuntime` snapshots include persisted accepted items when the
  registry is loaded, so the page does not appear empty after restart.

## Impact

- Affects RSS runtime snapshot projection, RSS page UI, RSS widget tests, and
  focused RSS runtime tests.
- Does not add RSS auto-download rule editing, torrent task creation, Bangumi
  matching, yuc.wiki special casing, or HTML scraping.
