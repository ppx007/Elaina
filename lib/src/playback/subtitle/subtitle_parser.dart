import 'subtitle_cue.dart';
import 'subtitle_source.dart';

final class SubtitleParseRequest {
  const SubtitleParseRequest({
    required this.source,
    required this.content,
    this.encodingHint,
  });

  final SubtitleSource source;
  final String content;
  final String? encodingHint;
}

final class SubtitleParseResult {
  const SubtitleParseResult._({required this.track, required this.warnings});

  const SubtitleParseResult.success(SubtitleTrack track, {List<String> warnings = const <String>[]})
      : this._(track: track, warnings: warnings);

  factory SubtitleParseResult.empty({required SubtitleSource source, String? warning}) {
    return SubtitleParseResult._(
      track: SubtitleTrack(source: source, cues: const <SubtitleCue>[]),
      warnings: <String>[if (warning != null) warning],
    );
  }

  final SubtitleTrack track;
  final List<String> warnings;
}

abstract interface class SubtitleParser {
  SubtitleFormat get format;

  Future<SubtitleParseResult> parse(SubtitleParseRequest request);
}

abstract interface class SubtitleParserRegistry {
  SubtitleParser? parserFor(SubtitleFormat format);
}
