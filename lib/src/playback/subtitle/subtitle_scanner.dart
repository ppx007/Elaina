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

final class DeterministicSubtitleFileCandidate {
  const DeterministicSubtitleFileCandidate({
    required this.uri,
    required this.basename,
    this.languageCode,
    this.title,
  }) : assert(basename != '', 'Subtitle candidate basename must not be empty.');

  final Uri uri;
  final String basename;
  final String? languageCode;
  final String? title;
}

final class DeterministicLocalExternalSubtitleScanner implements LocalExternalSubtitleScanner {
  const DeterministicLocalExternalSubtitleScanner({
    required List<DeterministicSubtitleFileCandidate> candidates,
  }) : _candidates = candidates;

  final List<DeterministicSubtitleFileCandidate> _candidates;

  @override
  Future<List<ExternalSubtitleCandidate>> scan(SubtitleScanRequest request) async {
    final String mediaStem = _basenameStem(request.media.basename).toLowerCase();
    final List<ExternalSubtitleCandidate> results = <ExternalSubtitleCandidate>[];
    for (final DeterministicSubtitleFileCandidate candidate in _candidates) {
      final SubtitleFormat? format = _formatForBasename(candidate.basename);
      if (format == null || !request.allowedFormats.contains(format)) continue;
      final String candidateStem = _basenameStem(candidate.basename).toLowerCase();
      final double confidence;
      if (candidateStem == mediaStem) {
        confidence = 1;
      } else if (candidateStem.startsWith('$mediaStem.')) {
        confidence = 0.9;
      } else if (candidateStem.contains(mediaStem)) {
        confidence = 0.6;
      } else {
        continue;
      }
      results.add(
        ExternalSubtitleCandidate(
          source: ExternalSubtitleSource(
            id: candidate.uri.toString(),
            format: format,
            languageCode: candidate.languageCode,
            uri: candidate.uri,
            title: candidate.title ?? candidate.basename,
          ),
          matchConfidence: confidence,
        ),
      );
    }
    results.sort(
      (ExternalSubtitleCandidate left, ExternalSubtitleCandidate right) => right.matchConfidence.compareTo(left.matchConfidence),
    );
    return List<ExternalSubtitleCandidate>.unmodifiable(results);
  }
}

SubtitleFormat? _formatForBasename(String basename) {
  final String lower = basename.toLowerCase();
  if (lower.endsWith('.srt')) return SubtitleFormat.srt;
  if (lower.endsWith('.vtt') || lower.endsWith('.webvtt')) return SubtitleFormat.vtt;
  if (lower.endsWith('.ass')) return SubtitleFormat.ass;
  return null;
}

String _basenameStem(String basename) {
  final int slash = basename.lastIndexOf('/');
  final int backslash = basename.lastIndexOf('\\');
  final int separator = slash > backslash ? slash : backslash;
  final String name = separator >= 0 ? basename.substring(separator + 1) : basename;
  final int dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}
