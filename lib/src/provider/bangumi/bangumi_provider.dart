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

final class BangumiPersonId {
  const BangumiPersonId(this.value)
      : assert(value != '', 'Bangumi person id must not be empty.');

  final String value;
}

final class BangumiCharacterId {
  const BangumiCharacterId(this.value)
      : assert(value != '', 'Bangumi character id must not be empty.');

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

final class BangumiRelatedPerson {
  const BangumiRelatedPerson({
    required this.id,
    required this.name,
    required this.relation,
    this.imageUri,
    this.careers = const <String>[],
    this.episodeRange,
  })  : assert(name != '', 'Bangumi related person name must not be empty.'),
        assert(relation != '',
            'Bangumi related person relation must not be empty.');

  final BangumiPersonId id;
  final String name;
  final String relation;
  final Uri? imageUri;
  final List<String> careers;
  final String? episodeRange;
}

final class BangumiVoiceActor {
  const BangumiVoiceActor({
    required this.id,
    required this.name,
    this.imageUri,
    this.careers = const <String>[],
  }) : assert(name != '', 'Bangumi voice actor name must not be empty.');

  final BangumiPersonId id;
  final String name;
  final Uri? imageUri;
  final List<String> careers;
}

final class BangumiRelatedCharacter {
  const BangumiRelatedCharacter({
    required this.id,
    required this.name,
    required this.relation,
    this.summary,
    this.imageUri,
    this.actors = const <BangumiVoiceActor>[],
  })  : assert(name != '', 'Bangumi related character name must not be empty.'),
        assert(relation != '',
            'Bangumi related character relation must not be empty.');

  final BangumiCharacterId id;
  final String name;
  final String relation;
  final String? summary;
  final Uri? imageUri;
  final List<BangumiVoiceActor> actors;
}

final class BangumiRelatedSubject {
  const BangumiRelatedSubject({
    required this.id,
    required this.title,
    required this.relation,
    this.coverUri,
    this.type,
  })  : assert(title != '', 'Bangumi related subject title must not be empty.'),
        assert(relation != '',
            'Bangumi related subject relation must not be empty.');

  final BangumiSubjectId id;
  final String title;
  final String relation;
  final Uri? coverUri;
  final int? type;
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

  Future<AcgProviderResult<List<BangumiRelatedPerson>>> listSubjectPersons(
    BangumiSubjectId subjectId,
  );

  Future<AcgProviderResult<List<BangumiRelatedCharacter>>>
      listSubjectCharacters(
    BangumiSubjectId subjectId,
  );

  Future<AcgProviderResult<List<BangumiRelatedSubject>>> listSubjectRelations(
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
