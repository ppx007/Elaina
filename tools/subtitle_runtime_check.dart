import '../lib/celesteria.dart';

Future<void> main() async {
  await verifyBasicSubtitleRuntimeContract();
}

Future<void> verifyBasicSubtitleRuntimeContract() async {
  final BasicSubtitleParserRegistry registry = BasicSubtitleParserRegistry.defaults();
  _expect(registry.parserFor(SubtitleFormat.srt) is SrtSubtitleParser, 'Default registry must expose SRT parser.');
  _expect(registry.parserFor(SubtitleFormat.vtt) is WebVttSubtitleParser, 'Default registry must expose WebVTT parser.');
  _expect(registry.parserFor(SubtitleFormat.ass) is BasicAssSubtitleParser, 'Default registry must expose ASS parser.');

  final BasicSubtitleRuntime runtime = BasicSubtitleRuntime(
    scanner: DeterministicLocalExternalSubtitleScanner(
      candidates: <DeterministicSubtitleFileCandidate>[
        DeterministicSubtitleFileCandidate(
          uri: Uri.file('D:/media/check.zh-Hans.srt'),
          basename: 'check.zh-Hans.srt',
          languageCode: 'zh-Hans',
        ),
      ],
    ),
  );
  final BasicSubtitleScanResult scan = await runtime.scan(
    SubtitleScanRequest(media: LocalMediaReference(uri: Uri.file('D:/media/check.mkv'), basename: 'check.mkv')),
  );
  _expect(scan.isSuccess, 'Subtitle scanner must succeed deterministically.');
  _expect(scan.candidates.single.source.format == SubtitleFormat.srt, 'Scanner must normalize subtitle format.');

  final ExternalSubtitleSource source = scan.candidates.single.source;
  final BasicSubtitleLoadResult load = await runtime.load(
    SubtitleParseRequest(
      source: source,
      content: '1\n00:00:02,000 --> 00:00:04,000\n字幕\n',
    ),
  );
  _expect(load.isSuccess, 'Runtime must load SRT track.');
  _expect(runtime.select(source).isSuccess, 'Runtime must select loaded subtitle source.');
  runtime.setOffset(const SubtitleOffset(Duration(seconds: 1)));
  final BasicSubtitleRuntimeSnapshot snapshot = runtime.resolveActiveCues(
    const PlayerClockSnapshot(position: Duration(seconds: 1), isPlaying: true, playbackSpeed: 1),
  );
  _expect(snapshot.activeCues.single.text == '字幕', 'Runtime must resolve offset active cues.');
  _expect(playbackSubtitleStateFromRuntimeSnapshot(snapshot).activeCues.single.text == '字幕', 'Runtime snapshot must project into Domain subtitle state.');
  runtime.dispose();
  _expect(runtime.isDisposed, 'Runtime must report disposed state.');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
