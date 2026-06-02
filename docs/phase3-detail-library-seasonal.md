# Phase 3: Detail, Library, Subtitle Provider, RSS, Seasonal Indexer

This phase adds contract scaffolding for Celesteria architecture plan steps 13-17.

## Implemented Boundary

- Video detail page data is exposed through Domain contracts and a thin UI-facing contract.
- Media library contracts define local identity, scan candidates, playback history, continue-watching state, and provider bindings.
- Subtitle providers are gateway-bound external discovery/retrieval contracts and return parser-compatible subtitle candidates.
- RSS/Atom contracts define source, fetch, parse, schedule, refresh, and stable deduplication boundaries.
- YucWiki seasonal data is modeled as a normal RSS `FeedSource`, then consumed into normalized seasonal catalog entries and a Bangumi match queue.

## Non-Goals Preserved

- No RSS auto-download behavior.
- No online rule-source parsing.
- No BT playback, torrent streaming, virtual streams, diagnostics center, Anime4K, VLC fallback, DNS policy, or WebView challenge handling.
- No concrete provider SDK or network client is introduced.

The next change should move into the Phase 4 boundary only after this change is archived.
