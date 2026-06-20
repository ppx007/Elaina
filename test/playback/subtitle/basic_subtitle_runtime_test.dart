import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deterministic scanner discovers media-adjacent subtitle candidates',
      () async {
    final DeterministicLocalExternalSubtitleScanner scanner =
        DeterministicLocalExternalSubtitleScanner(
      candidates: <DeterministicSubtitleFileCandidate>[
        DeterministicSubtitleFileCandidate(
          uri: Uri.file('D:/media/example.ja.srt'),
          basename: 'example.ja.srt',
          languageCode: 'ja',
        ),
        DeterministicSubtitleFileCandidate(
          uri: Uri.file('D:/media/other.srt'),
          basename: 'other.srt',
        ),
      ],
    );

    final List<ExternalSubtitleCandidate> candidates = await scanner.scan(
      SubtitleScanRequest(
          media: LocalMediaReference(
              uri: Uri.file('D:/media/example.mkv'), basename: 'example.mkv')),
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.source.languageCode, 'ja');
    expect(candidates.single.matchConfidence, 0.9);
  });

  test('runtime loads selects offsets and projects active cues', () async {
    final BasicSubtitleRuntime runtime = BasicSubtitleRuntime(
      scanner: const DeterministicLocalExternalSubtitleScanner(
          candidates: <DeterministicSubtitleFileCandidate>[]),
    );
    final _SubtitleObserver observer = _SubtitleObserver();
    runtime.addObserver(observer);

    final ExternalSubtitleSource source = ExternalSubtitleSource(
      id: 'subtitle-ja',
      format: SubtitleFormat.srt,
      languageCode: 'ja',
      uri: Uri.file('D:/media/example.ja.srt'),
    );
    final BasicSubtitleLoadResult load = await runtime.load(
      SubtitleParseRequest(
        source: source,
        content: '1\n00:00:02,000 --> 00:00:04,000\nこんにちは\n',
      ),
    );

    expect(load.isSuccess, isTrue);
    expect(runtime.select(source).isSuccess, isTrue);
    runtime.setOffset(const SubtitleOffset(Duration(seconds: 1)));
    final BasicSubtitleRuntimeSnapshot snapshot = runtime.resolveActiveCues(
      const PlayerClockSnapshot(
          position: Duration(seconds: 1), isPlaying: true, playbackSpeed: 1),
    );

    expect(snapshot.activeCues.single.text, 'こんにちは');
    expect(observer.snapshots, isNotEmpty);

    final PlaybackSubtitleStateSnapshot domainState =
        playbackSubtitleStateFromRuntimeSnapshot(snapshot);
    final PlaybackPageSurfaceDescriptor surface =
        PlaybackPageSurfaceDescriptor.fromState(
      const PlaybackSurfaceState(
        visibleControls: <PlaybackSurfaceControl>{
          PlaybackSurfaceControl.subtitleTracks
        },
        availablePanels: <PlaybackSurfacePanel>{PlaybackSurfacePanel.tracks},
      ),
      subtitles: domainState,
    );
    expect(surface.subtitleOverlay.cues.single.text, 'こんにちは');

    runtime.dispose();
  });

  test('runtime snapshots are defensive and disposed operations normalize',
      () async {
    final BasicSubtitleRuntime runtime = BasicSubtitleRuntime();
    final ExternalSubtitleSource source = ExternalSubtitleSource(
      id: 'subtitle-en',
      format: SubtitleFormat.vtt,
      uri: Uri.file('D:/media/example.vtt'),
    );

    await runtime.load(
      SubtitleParseRequest(
        source: source,
        content: 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n',
      ),
    );
    final BasicSubtitleRuntimeSnapshot retained = runtime.currentSnapshot;
    expect(
        () => retained.loadedTracks
            .add(SubtitleTrack(source: source, cues: const <SubtitleCue>[])),
        throwsUnsupportedError);

    runtime.dispose();
    final BasicSubtitleLoadResult disposed =
        await runtime.load(SubtitleParseRequest(source: source, content: ''));
    expect(disposed.failure?.kind, BasicSubtitleRuntimeFailureKind.disposed);
  });
}

final class _SubtitleObserver implements BasicSubtitleRuntimeObserver {
  final List<BasicSubtitleRuntimeSnapshot> snapshots =
      <BasicSubtitleRuntimeSnapshot>[];

  @override
  void onSubtitleRuntimeSnapshot(BasicSubtitleRuntimeSnapshot snapshot) {
    snapshots.add(snapshot);
  }
}
