import '../../foundation/extension_points.dart';
import '../gateway_bound_provider.dart';
import '../provider_result.dart';

final class BangumiSubjectId {
  const BangumiSubjectId(this.value)
      : assert(value != '', 'Bangumi subject id must not be empty.');

  final String value;
}

final class BangumiEpisodeId {
  const BangumiEpisodeId(this.value)
      : assert(value != '', 'Bangumi episode id must not be empty.');

  final String value;
}

final class BangumiSubject {
  const BangumiSubject({
    required this.id,
    required this.title,
    this.summary,
    this.coverUri,
    this.rank,
    this.score,
    this.collectionTotal,
    this.episodeCount,
  });

  final BangumiSubjectId id;
  final String title;
  final String? summary;
  final Uri? coverUri;
  final int? rank;
  final double? score;
  final int? collectionTotal;
  final int? episodeCount;
}

final class BangumiEpisode {
  const BangumiEpisode(
      {required this.id,
      required this.subjectId,
      required this.index,
      required this.title});

  final BangumiEpisodeId id;
  final BangumiSubjectId subjectId;
  final int index;
  final String title;
}

abstract interface class BangumiProvider implements GatewayBoundProvider {
  @override
  ProviderKind get kind => ProviderKind.metadata;

  Future<AcgProviderResult<BangumiSubject>> lookupSubject(BangumiSubjectId id);

  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(String query);

  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(BangumiEpisodeId id);

  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  );
}

abstract interface class BangumiDiscoveryProvider {
  Future<AcgProviderResult<List<BangumiSubject>>> popularAnime();

  Future<AcgProviderResult<List<BangumiSubject>>> recentPopularAnime({
    required DateTime now,
    required int limit,
    required int offset,
  });
}
