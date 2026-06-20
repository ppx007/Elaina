import '../../foundation/extension_points.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';

final class DandanplayAnimeId {
  const DandanplayAnimeId(this.value)
      : assert(value != '', 'Dandanplay anime id must not be empty.');

  final String value;
}

final class DandanplayEpisodeId {
  const DandanplayEpisodeId(this.value)
      : assert(value != '', 'Dandanplay episode id must not be empty.');

  final String value;
}

final class DandanplayMatchCandidate {
  const DandanplayMatchCandidate({
    required this.animeId,
    required this.episodeId,
    required this.title,
    required this.confidence,
  }) : assert(confidence >= 0 && confidence <= 1,
            'confidence must be between 0 and 1.');

  final DandanplayAnimeId animeId;
  final DandanplayEpisodeId episodeId;
  final String title;
  final double confidence;
}

abstract interface class DandanplayProvider implements GatewayBoundProvider {
  @override
  ProviderKind get kind => ProviderKind.danmaku;

  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> matchLocalMedia(
      String filename);

  Future<AcgProviderResult<List<DandanplayMatchCandidate>>> search(
      String query);
}
