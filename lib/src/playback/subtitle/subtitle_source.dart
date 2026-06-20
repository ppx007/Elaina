enum SubtitleFormat {
  srt,
  vtt,
  ass,
}

sealed class SubtitleSource {
  const SubtitleSource(
      {required this.id, required this.format, this.languageCode});

  final String id;
  final SubtitleFormat format;
  final String? languageCode;
}

final class EmbeddedSubtitleSource extends SubtitleSource {
  const EmbeddedSubtitleSource({
    required super.id,
    required super.format,
    super.languageCode,
    required this.trackId,
  });

  final String trackId;
}

final class ExternalSubtitleSource extends SubtitleSource {
  const ExternalSubtitleSource({
    required super.id,
    required super.format,
    super.languageCode,
    required this.uri,
    this.title,
  });

  final Uri uri;
  final String? title;
}

final class LocalMediaReference {
  const LocalMediaReference({required this.uri, required this.basename});

  final Uri uri;
  final String basename;
}
