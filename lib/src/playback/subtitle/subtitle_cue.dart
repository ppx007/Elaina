import 'subtitle_source.dart';

final class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
    this.id,
    this.settings = const <String, String>{},
  }) : assert(end >= start, 'Subtitle cue end must not precede start.');

  final Duration start;
  final Duration end;
  final String text;
  final String? id;
  final Map<String, String> settings;

  bool isActiveAt(Duration position) {
    return position >= start && position < end;
  }
}

final class SubtitleTrack {
  const SubtitleTrack({
    required this.source,
    required this.cues,
    this.title,
    this.styleMetadata = const <String, String>{},
  });

  final SubtitleSource source;
  final List<SubtitleCue> cues;
  final String? title;
  final Map<String, String> styleMetadata;
}
