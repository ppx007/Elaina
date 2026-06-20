import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SRT parser normalizes timing text and cue ids', () async {
    const SrtSubtitleParser parser = SrtSubtitleParser();

    final SubtitleParseResult result = await parser.parse(
      SubtitleParseRequest(
        source: _source(SubtitleFormat.srt),
        content:
            '\uFEFF1\n00:00:01,500 --> 00:00:03,000\nHello\nworld\n\n3\n00:00:02.000 --> 00:00:04.000\nOverlap\n',
      ),
    );

    expect(result.track.cues, hasLength(2));
    expect(result.track.cues.first.id, '1');
    expect(result.track.cues.first.start, const Duration(milliseconds: 1500));
    expect(result.track.cues.first.text, 'Hello\nworld');
    expect(result.track.cues.last.text, 'Overlap');
  });

  test('WebVTT parser handles identifiers settings and NOTE blocks', () async {
    const WebVttSubtitleParser parser = WebVttSubtitleParser();

    final SubtitleParseResult result = await parser.parse(
      SubtitleParseRequest(
        source: _source(SubtitleFormat.vtt),
        content:
            'WEBVTT\n\nNOTE ignored\ncomment\n\nintro\n00:01.000 --> 00:03.250 align:center line:90%\n<v narrator>Hello</v>\n',
      ),
    );

    expect(result.track.cues, hasLength(1));
    expect(result.track.cues.single.id, 'intro');
    expect(result.track.cues.single.start, const Duration(seconds: 1));
    expect(result.track.cues.single.end, const Duration(milliseconds: 3250));
    expect(result.track.cues.single.settings['align'], 'center');
    expect(result.track.cues.single.settings['line'], '90%');
  });

  test('basic ASS parser extracts dialogue text and ignores override tags',
      () async {
    const BasicAssSubtitleParser parser = BasicAssSubtitleParser();

    final SubtitleParseResult result = await parser.parse(
      SubtitleParseRequest(
        source: _source(SubtitleFormat.ass),
        content:
            '[Script Info]\nTitle: Example\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:01.20,0:00:03.40,Default,,0,0,0,,{\\i1}Hello, world\\NLine 2\n',
      ),
    );

    expect(result.track.cues, hasLength(1));
    expect(result.track.cues.single.start, const Duration(milliseconds: 1200));
    expect(result.track.cues.single.end, const Duration(milliseconds: 3400));
    expect(result.track.cues.single.text, 'Hello, world\nLine 2');
    expect(result.track.cues.single.settings['style'], 'Default');
  });

  test('parser registry exposes default parsers and empty results warn',
      () async {
    final BasicSubtitleParserRegistry registry =
        BasicSubtitleParserRegistry.defaults();

    expect(registry.parserFor(SubtitleFormat.srt), isA<SrtSubtitleParser>());
    expect(registry.parserFor(SubtitleFormat.vtt), isA<WebVttSubtitleParser>());
    expect(
        registry.parserFor(SubtitleFormat.ass), isA<BasicAssSubtitleParser>());

    final SubtitleParseResult empty =
        await registry.parserFor(SubtitleFormat.srt)!.parse(
              SubtitleParseRequest(
                  source: _source(SubtitleFormat.srt), content: ''),
            );
    expect(empty.track.cues, isEmpty);
    expect(empty.warnings.single, contains('No SRT cues'));
  });
}

ExternalSubtitleSource _source(SubtitleFormat format) {
  return ExternalSubtitleSource(
    id: 'subtitle-${format.name}',
    format: format,
    uri: Uri.file('D:/media/example.${format.name}'),
  );
}
