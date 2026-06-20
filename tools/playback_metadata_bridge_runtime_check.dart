import '../lib/elaina.dart';

Future<void> main() async {
  await verifyPlaybackMetadataBridgeRuntimeContract();
}

Future<void> verifyPlaybackMetadataBridgeRuntimeContract() async {
  final PlaybackMetadataBridge bridge = PlaybackMetadataBridge(
    subtitleRuntime: BasicSubtitleRuntime(),
    danmakuRuntime: BasicDanmakuRuntime(),
  );
  final ExternalSubtitleSource source = ExternalSubtitleSource(
    id: 'bridge-check-subtitle',
    format: SubtitleFormat.srt,
    uri: Uri.file('D:/media/bridge-check.srt'),
    title: 'Bridge Check Subtitle',
  );
  final PlaybackMetadataBridgeResult<PlaybackSubtitleStateSnapshot> subtitle =
      await bridge.loadPreparedSubtitle(
    SubtitleParseRequest(
      source: source,
      content: '1\n00:00:01,000 --> 00:00:02,000\nbridge-subtitle',
      encodingHint: 'utf-8',
    ),
  );
  _expect(subtitle.isSuccess, 'Bridge must load prepared subtitle requests.');

  final PlaybackMetadataBridgeResult<PlaybackDanmakuStateSnapshot> danmaku =
      bridge.loadDandanplayCommentValues(
    const <DandanplayComment>[
      DandanplayComment(
        timestamp: Duration(seconds: 1),
        text: 'bridge-danmaku',
        mode: DandanplayCommentMode.scrolling,
      ),
    ],
    idPrefix: 'bridge-check-episode',
  );
  _expect(
      danmaku.isSuccess, 'Bridge must load normalized Dandanplay comments.');

  final PlaybackMetadataBridgeResult<PlaybackMetadataBridgeSnapshot> resolved =
      bridge.resolve(
    const PlayerClockSnapshot(
      position: Duration(seconds: 1),
      isPlaying: true,
      playbackSpeed: 1,
    ),
  );
  _expect(resolved.isSuccess, 'Bridge must resolve metadata for player clock.');
  final PlaybackMetadataBridgeSnapshot snapshot = resolved.value!;
  _expect(snapshot.subtitles.activeCues.single.text == 'bridge-subtitle',
      'Bridge must project active subtitle cues.');
  _expect(snapshot.danmaku.hasVisibleComments,
      'Bridge must project visible danmaku comments.');

  final PlaybackStateSnapshot state = snapshot.applyTo(
    PlaybackStateSnapshot(
      status: PlaybackLifecycleStatus.playing,
      sourceUri: Uri.file('D:/media/bridge-check.mkv'),
    ),
  );
  _expect(state.subtitles.activeCues.single.text == 'bridge-subtitle',
      'Bridge metadata must apply to playback state subtitles.');
  _expect(state.danmaku.hasVisibleComments,
      'Bridge metadata must apply to playback state danmaku.');

  bridge.dispose();
  _expect(
      bridge.currentSnapshot.status == PlaybackMetadataBridgeStatus.disposed,
      'Bridge dispose must publish disposed status.');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
