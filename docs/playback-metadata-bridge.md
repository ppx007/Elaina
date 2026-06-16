# Playback Metadata Bridge

Step 39 adds a Domain playback metadata bridge for subtitle and danmaku
handoff. It connects existing runtime pieces without adding UI:

- `SubtitleProviderRuntime` prepares provider subtitle files as
  `SubtitleParseRequest` values.
- `BasicSubtitleRuntime` parses and resolves active subtitle cues.
- `DandanplayCommentProvider` supplies provider comments.
- `BasicDanmakuRuntime` resolves clock-driven danmaku frames.
- `PlaybackMetadataBridge` projects both into framework-neutral playback state
  snapshots.

## Composition

App composition can wire the bridge after provider and playback runtimes are
available:

```dart
final bridge = PlaybackMetadataBridge(
  subtitleRuntime: BasicSubtitleRuntime(),
  danmakuRuntime: BasicDanmakuRuntime(),
  subtitleProviderRuntime: subtitleProviderBootstrap.runtime,
  dandanplayCommentProvider: dandanplayRuntime,
);
```

Provider subtitles can be loaded from an already selected candidate:

```dart
await bridge.loadProviderSubtitle(candidate);
final metadata = bridge.resolve(playerClock.current).value;
```

Dandanplay comments can be loaded from a selected episode id:

```dart
await bridge.loadDandanplayComments(episodeId);
final metadata = bridge.resolve(playerClock.current).value;
```

The resulting `PlaybackMetadataBridgeSnapshot` can be applied to an existing
`PlaybackStateSnapshot` using `applyTo`.

## Boundary

- UI must consume `PlaybackSubtitleStateSnapshot`,
  `PlaybackDanmakuStateSnapshot`, or `PlaybackStateSnapshot`; it must not import
  concrete provider clients.
- The bridge does not call Bangumi, OpenSubtitles, or Dandanplay HTTP clients
  directly.
- The bridge does not mutate native player subtitle tracks, MPV options, or
  Flutter overlays.
- Provider lookup, login, provider selection UI, subtitle search UI, danmaku
  panel UI, and advanced caption rendering remain separate work.
