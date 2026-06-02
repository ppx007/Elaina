import 'subtitle_source.dart';

final class SubtitleScanRequest {
  const SubtitleScanRequest({
    required this.media,
    this.allowedFormats = const <SubtitleFormat>{SubtitleFormat.srt, SubtitleFormat.vtt, SubtitleFormat.ass},
  });

  final LocalMediaReference media;
  final Set<SubtitleFormat> allowedFormats;
}

final class ExternalSubtitleCandidate {
  const ExternalSubtitleCandidate({
    required this.source,
    required this.matchConfidence,
  }) : assert(matchConfidence >= 0 && matchConfidence <= 1, 'matchConfidence must be between 0 and 1.');

  final ExternalSubtitleSource source;
  final double matchConfidence;
}

abstract interface class LocalExternalSubtitleScanner {
  Future<List<ExternalSubtitleCandidate>> scan(SubtitleScanRequest request);
}
