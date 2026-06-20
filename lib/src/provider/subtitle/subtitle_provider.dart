import '../../foundation/extension_points.dart';
import '../../foundation/gateway/provider_gateway.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';

final class SubtitleProviderId {
  const SubtitleProviderId(this.value)
      : assert(value != '', 'Subtitle provider id must not be empty.');

  final String value;
}

final class SubtitleSearchQuery {
  const SubtitleSearchQuery({
    required this.title,
    required this.languageCode,
    this.seasonNumber,
    this.episodeNumber,
    this.localMediaUri,
  })  : assert(title != '', 'Subtitle query title must not be empty.'),
        assert(
            languageCode != '', 'Subtitle query language must not be empty.');

  final String title;
  final String languageCode;
  final int? seasonNumber;
  final int? episodeNumber;
  final Uri? localMediaUri;
}

enum ProviderSubtitleFormat {
  srt,
  vtt,
  ass,
}

final class SubtitleProviderCandidate {
  const SubtitleProviderCandidate({
    required this.id,
    required this.providerId,
    required this.title,
    required this.format,
    required this.reference,
    required this.confidence,
    this.languageCode,
    this.sourceUri,
  })  : assert(id != '', 'Subtitle candidate id must not be empty.'),
        assert(title != '', 'Subtitle candidate title must not be empty.'),
        assert(
            reference != '', 'Subtitle candidate reference must not be empty.'),
        assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

  final String id;
  final SubtitleProviderId providerId;
  final String title;
  final ProviderSubtitleFormat format;
  final String reference;
  final double confidence;
  final String? languageCode;
  final Uri? sourceUri;
}

final class RetrievedSubtitleFile {
  const RetrievedSubtitleFile({
    required this.candidate,
    required this.content,
    this.encodingHint,
    this.cachedUri,
  }) : assert(content != '', 'Retrieved subtitle content must not be empty.');

  final SubtitleProviderCandidate candidate;
  final String content;
  final String? encodingHint;
  final Uri? cachedUri;
}

final class SubtitleProviderCachePolicy {
  const SubtitleProviderCachePolicy({
    required this.searchTtl,
    required this.fileTtl,
    this.gatewayPolicy = ProviderCachePolicy.networkFirst,
  })  : assert(searchTtl > Duration.zero, 'searchTtl must be positive.'),
        assert(fileTtl > Duration.zero, 'fileTtl must be positive.');

  final Duration searchTtl;
  final Duration fileTtl;
  final ProviderCachePolicy gatewayPolicy;
}

abstract interface class SubtitleProvider implements GatewayBoundProvider {
  @override
  ProviderKind get kind => ProviderKind.subtitle;

  SubtitleProviderId get subtitleProviderId;

  SubtitleProviderCachePolicy get cachePolicy;

  Future<AcgProviderResult<List<SubtitleProviderCandidate>>> searchSubtitles(
      SubtitleSearchQuery query);

  Future<AcgProviderResult<RetrievedSubtitleFile>> retrieveSubtitle(
      SubtitleProviderCandidate candidate);
}
