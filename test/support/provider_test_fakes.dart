import 'package:elaina/elaina.dart';

const String fakeBangumiProviderId = 'fake-bangumi';

final class RecordingProviderGateway implements ProviderGateway {
  RecordingProviderGateway({this.proxyUrl});

  final DeterministicStorageFoundation _storage =
      DeterministicStorageFoundation();
  final String? proxyUrl;
  String? registeredProviderId;
  String? lastCacheKey;
  ProviderCachePolicy? lastCachePolicy;
  Duration? lastDeduplicationWindow;
  Uri? lastNetworkPolicyUri;

  @override
  StorageFoundation get storage => _storage;

  @override
  Future<void> registerProvider(ProviderRegistration registration) async {
    registeredProviderId = registration.providerId.value;
  }

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
    ProviderGatewayRequest<T> request,
  ) async {
    lastCacheKey = request.key.cacheKey;
    lastCachePolicy = request.cachePolicy;
    lastDeduplicationWindow = request.deduplicationWindow;
    lastNetworkPolicyUri = request.networkPolicyUri;
    return ProviderGatewayResponse<T>(
      value: await request.executeLoad(
        ProviderGatewayRequestContext(proxyUrl: proxyUrl),
      ),
      source: ProviderGatewayResponseSource.network,
    );
  }
}

final class FailingProviderGateway implements ProviderGateway {
  FailingProviderGateway(this.kind);

  final ProviderFailureKind kind;
  final DeterministicStorageFoundation _storage =
      DeterministicStorageFoundation();

  @override
  StorageFoundation get storage => _storage;

  @override
  Future<void> registerProvider(ProviderRegistration registration) async {}

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
    ProviderGatewayRequest<T> request,
  ) {
    return Future<ProviderGatewayResponse<T>>.error(
      ProviderFailure(kind: kind, message: 'Injected gateway failure.'),
    );
  }
}

final class UnsupportedProviderGateway implements ProviderGateway {
  const UnsupportedProviderGateway();

  @override
  StorageFoundation get storage =>
      throw UnsupportedError('Gateway storage is not used by this test.');

  @override
  Future<void> registerProvider(ProviderRegistration registration) {
    throw UnsupportedError('Provider registration is not used by this test.');
  }

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
    ProviderGatewayRequest<T> request,
  ) {
    throw UnsupportedError('Gateway execution is not used by this test.');
  }
}

final class FakeBangumiTransport implements BangumiApiTransport {
  FakeBangumiTransport({
    required Map<String, BangumiApiResponse> responses,
  }) : _responses = responses;

  final Map<String, BangumiApiResponse> _responses;
  final List<BangumiApiRequest> requests = <BangumiApiRequest>[];

  @override
  Future<BangumiApiResponse> send(BangumiApiRequest request) async {
    requests.add(request);
    return _responses[_requestKey(request)] ??
        const BangumiApiResponse(
          statusCode: 404,
          body: '{"title":"missing fake response"}',
        );
  }
}

final class QueuedBangumiTransport implements BangumiApiTransport {
  QueuedBangumiTransport(Iterable<Object> outcomes)
      : _outcomes = List<Object>.of(outcomes);

  final List<Object> _outcomes;
  final List<BangumiApiRequest> requests = <BangumiApiRequest>[];

  @override
  Future<BangumiApiResponse> send(BangumiApiRequest request) async {
    requests.add(request);
    if (_outcomes.isEmpty) {
      return const BangumiApiResponse(
        statusCode: 404,
        body: '{"title":"missing fake response"}',
      );
    }
    final Object outcome = _outcomes.removeAt(0);
    if (outcome is BangumiApiResponse) return outcome;
    if (outcome is Exception) throw outcome;
    throw StateError('Unsupported queued Bangumi transport outcome: $outcome');
  }
}

final class FakeBangumiProvider implements BangumiProvider {
  FakeBangumiProvider({
    Iterable<BangumiSubject> subjects = const <BangumiSubject>[],
    Map<String, BangumiSubject> subjectsById = const <String, BangumiSubject>{},
    Map<String, List<BangumiSubject>> searchResultsByQuery =
        const <String, List<BangumiSubject>>{},
    Map<String, BangumiEpisode> episodesById = const <String, BangumiEpisode>{},
    Map<String, List<BangumiEpisode>> episodesBySubjectId =
        const <String, List<BangumiEpisode>>{},
    Map<String, List<BangumiRelatedPerson>> personsBySubjectId =
        const <String, List<BangumiRelatedPerson>>{},
    Map<String, List<BangumiRelatedCharacter>> charactersBySubjectId =
        const <String, List<BangumiRelatedCharacter>>{},
    Map<String, List<BangumiRelatedSubject>> relationsBySubjectId =
        const <String, List<BangumiRelatedSubject>>{},
    this.searchFailureKind,
    this.lookupFailureKind,
    this.episodeFailureKind,
    this.personsFailureKind,
    this.charactersFailureKind,
    this.relationsFailureKind,
    this.lookupFailureMessage = 'Missing subject.',
    this.episodeFailureMessage = 'Episode lookup is not part of this test.',
    this.providerId = fakeBangumiProviderId,
  })  : _subjectsById = <String, BangumiSubject>{
          for (final BangumiSubject subject in subjects)
            subject.id.value: subject,
          ...subjectsById,
        },
        _searchResultsByQuery = searchResultsByQuery,
        _episodesById = episodesById,
        _episodesBySubjectId = episodesBySubjectId,
        _personsBySubjectId = personsBySubjectId,
        _charactersBySubjectId = charactersBySubjectId,
        _relationsBySubjectId = relationsBySubjectId;

  final Map<String, BangumiSubject> _subjectsById;
  final Map<String, List<BangumiSubject>> _searchResultsByQuery;
  final Map<String, BangumiEpisode> _episodesById;
  final Map<String, List<BangumiEpisode>> _episodesBySubjectId;
  final Map<String, List<BangumiRelatedPerson>> _personsBySubjectId;
  final Map<String, List<BangumiRelatedCharacter>> _charactersBySubjectId;
  final Map<String, List<BangumiRelatedSubject>> _relationsBySubjectId;
  final AcgProviderFailureKind? searchFailureKind;
  final AcgProviderFailureKind? lookupFailureKind;
  final AcgProviderFailureKind? episodeFailureKind;
  final AcgProviderFailureKind? personsFailureKind;
  final AcgProviderFailureKind? charactersFailureKind;
  final AcgProviderFailureKind? relationsFailureKind;
  final String lookupFailureMessage;
  final String episodeFailureMessage;
  final String providerId;
  final List<String> searchedQueries = <String>[];

  @override
  String get displayName => 'Fake Bangumi Provider';

  @override
  ProviderGateway get gateway => const UnsupportedProviderGateway();

  @override
  String get id => providerId;

  @override
  ProviderKind get kind => ProviderKind.metadata;

  @override
  ProviderRegistration get registration => ProviderRegistration(
        providerId: ProviderId(providerId),
        ratePolicy: const ProviderRatePolicy(
          maxRequests: 12,
          window: Duration(minutes: 1),
        ),
        retryPolicy: const ProviderRetryPolicy(
          maxAttempts: 3,
          initialBackoff: Duration(seconds: 1),
        ),
      );

  @override
  Future<ProviderGatewayResponse<T>> executeGatewayRequest<T>({
    required String cacheKey,
    required Future<T> Function() load,
    ProviderCachePolicy cachePolicy = ProviderCachePolicy.networkOnly,
  }) async {
    return ProviderGatewayResponse<T>(
      value: await load(),
      source: ProviderGatewayResponseSource.network,
    );
  }

  @override
  Future<AcgProviderResult<BangumiEpisode>> lookupEpisode(
    BangumiEpisodeId id,
  ) {
    final AcgProviderFailureKind? failureKind = episodeFailureKind;
    if (failureKind != null) {
      return Future<AcgProviderResult<BangumiEpisode>>.value(
        AcgProviderFailure<BangumiEpisode>(
          kind: failureKind,
          message: episodeFailureMessage,
        ),
      );
    }
    final BangumiEpisode? episode = _episodesById[id.value];
    if (episode == null) {
      return Future<AcgProviderResult<BangumiEpisode>>.value(
        AcgProviderFailure<BangumiEpisode>(
          kind: AcgProviderFailureKind.unavailable,
          message: episodeFailureMessage,
        ),
      );
    }
    return Future<AcgProviderResult<BangumiEpisode>>.value(
      AcgProviderSuccess<BangumiEpisode>(episode),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiEpisode>>> listEpisodes(
    BangumiSubjectId subjectId,
  ) {
    final AcgProviderFailureKind? failureKind = episodeFailureKind;
    if (failureKind != null) {
      return Future<AcgProviderResult<List<BangumiEpisode>>>.value(
        AcgProviderFailure<List<BangumiEpisode>>(
          kind: failureKind,
          message: episodeFailureMessage,
        ),
      );
    }
    return Future<AcgProviderResult<List<BangumiEpisode>>>.value(
      AcgProviderSuccess<List<BangumiEpisode>>(
        _episodesBySubjectId[subjectId.value] ?? const <BangumiEpisode>[],
      ),
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedPerson>>> listSubjectPersons(
    BangumiSubjectId subjectId,
  ) {
    return _listOrFailure<BangumiRelatedPerson>(
      failureKind: personsFailureKind,
      failureMessage: 'Persons failed.',
      values: _personsBySubjectId[subjectId.value] ??
          const <BangumiRelatedPerson>[],
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedCharacter>>>
      listSubjectCharacters(
    BangumiSubjectId subjectId,
  ) {
    return _listOrFailure<BangumiRelatedCharacter>(
      failureKind: charactersFailureKind,
      failureMessage: 'Characters failed.',
      values: _charactersBySubjectId[subjectId.value] ??
          const <BangumiRelatedCharacter>[],
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiRelatedSubject>>> listSubjectRelations(
    BangumiSubjectId subjectId,
  ) {
    return _listOrFailure<BangumiRelatedSubject>(
      failureKind: relationsFailureKind,
      failureMessage: 'Relations failed.',
      values: _relationsBySubjectId[subjectId.value] ??
          const <BangumiRelatedSubject>[],
    );
  }

  @override
  Future<AcgProviderResult<BangumiSubject>> lookupSubject(
    BangumiSubjectId id,
  ) {
    final AcgProviderFailureKind? failureKind = lookupFailureKind;
    if (failureKind != null) {
      return Future<AcgProviderResult<BangumiSubject>>.value(
        AcgProviderFailure<BangumiSubject>(
          kind: failureKind,
          message: lookupFailureMessage,
        ),
      );
    }
    final BangumiSubject? subject = _subjectsById[id.value];
    if (subject == null) {
      return Future<AcgProviderResult<BangumiSubject>>.value(
        AcgProviderFailure<BangumiSubject>(
          kind: AcgProviderFailureKind.notFound,
          message: lookupFailureMessage,
        ),
      );
    }
    return Future<AcgProviderResult<BangumiSubject>>.value(
      AcgProviderSuccess<BangumiSubject>(subject),
    );
  }

  @override
  ProviderRequestKey requestKey(String cacheKey) {
    return ProviderRequestKey(
      providerId: ProviderId(providerId),
      cacheKey: cacheKey,
    );
  }

  @override
  Future<AcgProviderResult<List<BangumiSubject>>> searchSubjects(
    String query,
  ) {
    searchedQueries.add(query);
    final AcgProviderFailureKind? failureKind = searchFailureKind;
    if (failureKind != null) {
      return Future<AcgProviderResult<List<BangumiSubject>>>.value(
        AcgProviderFailure<List<BangumiSubject>>(
          kind: failureKind,
          message: 'Search failed.',
        ),
      );
    }
    return Future<AcgProviderResult<List<BangumiSubject>>>.value(
      AcgProviderSuccess<List<BangumiSubject>>(
        _searchResultsByQuery[query] ??
            <BangumiSubject>[..._subjectsById.values],
      ),
    );
  }

  Future<AcgProviderResult<List<T>>> _listOrFailure<T>({
    required AcgProviderFailureKind? failureKind,
    required String failureMessage,
    required List<T> values,
  }) {
    if (failureKind != null) {
      return Future<AcgProviderResult<List<T>>>.value(
        AcgProviderFailure<List<T>>(
          kind: failureKind,
          message: failureMessage,
        ),
      );
    }
    return Future<AcgProviderResult<List<T>>>.value(
      AcgProviderSuccess<List<T>>(values),
    );
  }
}

String _requestKey(BangumiApiRequest request) {
  final String query = request.uri.hasQuery ? '?${request.uri.query}' : '';
  return '${request.method} ${request.uri.path}$query';
}
