import 'dart:convert';
import 'dart:io';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_test_fakes.dart';

void main() {
  test(
      'runtime registers policy and looks up subject episode and search results',
      () async {
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-1017'),
      title: 'Elaina',
      summary: 'Deterministic ACG runtime',
    );
    final BangumiEpisode episode = BangumiEpisode(
      id: const BangumiEpisodeId('episode-1'),
      subjectId: subject.id,
      index: 1,
      title: 'Bootstrap',
    );
    final BangumiProviderRuntime runtime = BangumiProviderRuntime(
      gateway: gateway,
      subjects: <BangumiSubject>[subject],
      episodes: <BangumiEpisode>[episode],
    );

    final AcgProviderResult<BangumiSubject> subjectResult =
        await runtime.lookupSubject(subject.id);
    expect(subjectResult, isA<AcgProviderSuccess<BangumiSubject>>());
    expect(gateway.registeredProviderId, bangumiProviderId.value);
    expect(gateway.lastCacheKey, 'subject:subject-1017');
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkFirst);

    final AcgProviderResult<List<BangumiSubject>> searchResult =
        await runtime.searchSubjects('runtime');
    final List<BangumiSubject> matches =
        (searchResult as AcgProviderSuccess<List<BangumiSubject>>).value;
    expect(matches.single.title, 'Elaina');
    expect(gateway.lastCacheKey, 'subject-search:runtime');

    final AcgProviderResult<BangumiEpisode> episodeResult =
        await runtime.lookupEpisode(episode.id);
    expect((episodeResult as AcgProviderSuccess<BangumiEpisode>).value.title,
        'Bootstrap');
    expect(gateway.lastCacheKey, 'episode:episode-1');

    final AcgProviderResult<List<BangumiEpisode>> episodeListResult =
        await runtime.listEpisodes(subject.id);
    final List<BangumiEpisode> episodes =
        (episodeListResult as AcgProviderSuccess<List<BangumiEpisode>>).value;
    expect(episodes.single.id.value, 'episode-1');
    expect(gateway.lastCacheKey, 'episodes:subject-1017');
  });

  test(
      'request helpers preserve provider id semantic keys and cache request defaults',
      () {
    final ProviderRequestKey subjectKey =
        bangumiSubjectRequestKey(const BangumiSubjectId('42'));
    final ProviderRequestKey searchKey =
        bangumiSubjectSearchRequestKey('  ELaina  ');
    final ProviderRequestKey episodeKey =
        bangumiEpisodeRequestKey(const BangumiEpisodeId('7'));
    final ProviderRequestKey episodeListKey =
        bangumiEpisodeListRequestKey(const BangumiSubjectId('42'));
    final ProviderRequestKey recentPopularKey =
        bangumiRecentPopularAnimeRequestKey(
      now: DateTime.utc(2026, 6, 21),
      limit: 24,
      offset: 48,
    );
    final ProviderRequestKey popularKey = bangumiPopularAnimeRequestKey(
      now: DateTime.utc(2026, 6, 21),
    );
    final ProviderRequestKey collectionKey = bangumiAnimeCollectionRequestKey();
    final ProviderRequestKey subjectCollectionSyncKey =
        bangumiSubjectCollectionSyncRequestKey(
      const BangumiSubjectCollectionUpdate(
        subjectId: BangumiSubjectId('42'),
        status: BangumiSubjectCollectionStatus.dropped,
      ),
    );
    final ProviderGatewayRequest<String> request =
        bangumiGatewayRequest<String>(
      key: subjectKey,
      load: () async => 'ok',
    );

    expect(subjectKey.providerId.value, bangumiProviderId.value);
    expect(subjectKey.cacheKey, 'subject:42');
    expect(searchKey.cacheKey, 'subject-search:elaina');
    expect(popularKey.cacheKey, 'subject-popular-anime:20260621');
    expect(episodeKey.cacheKey, 'episode:7');
    expect(episodeListKey.cacheKey, 'episodes:42');
    expect(
      recentPopularKey.cacheKey,
      'subject-recent-popular-anime:20260621:24:48',
    );
    expect(collectionKey.cacheKey, 'anime-collection:current');
    expect(subjectCollectionSyncKey.cacheKey, 'subject-collection:42:dropped');
    expect(request.cachePolicy, ProviderCachePolicy.networkFirst);
    expect(request.deduplicationWindow, bangumiRuntimeDeduplicationWindow);
  });

  test('gateway failures normalize before reaching domain callers', () async {
    final FailingProviderGateway gateway =
        FailingProviderGateway(ProviderFailureKind.throttled);
    final DeterministicBangumiProvider provider =
        DeterministicBangumiProvider(gateway: gateway);

    final AcgProviderResult<BangumiSubject> result =
        await provider.lookupSubject(const BangumiSubjectId('missing'));

    expect(result, isA<AcgProviderFailure<BangumiSubject>>());
    expect((result as AcgProviderFailure<BangumiSubject>).kind,
        AcgProviderFailureKind.throttled);
  });

  test(
      'auth provider handles session sync unauthenticated and disposed runtime behavior',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 9);
    final BangumiProviderRuntime authenticated = BangumiProviderRuntime(
      gateway: RecordingProviderGateway(),
      session: BangumiAuthSession(
        userId: 'user-1',
        expiresAt: now.add(const Duration(days: 1)),
        avatarUri: Uri.parse('https://img.test/avatar.png'),
      ),
      animeCollection: const <BangumiAnimeCollectionItem>[
        BangumiAnimeCollectionItem(
          subjectId: BangumiSubjectId('subject-1017'),
          title: 'Elaina',
          status: BangumiSubjectCollectionStatus.watching,
          watchedEpisodes: 5,
          totalEpisodes: 12,
        ),
      ],
      now: () => now,
    );

    final AcgProviderResult<BangumiAuthSession> sessionResult =
        await authenticated.currentSession();
    final BangumiAuthSession session =
        (sessionResult as AcgProviderSuccess<BangumiAuthSession>).value;
    expect(session.userId, 'user-1');
    expect(session.avatarUri, Uri.parse('https://img.test/avatar.png'));

    final AcgProviderResult<void> syncResult = await authenticated.syncProgress(
      const BangumiProgressUpdate(
        subjectId: BangumiSubjectId('subject-1017'),
        episodeId: BangumiEpisodeId('episode-1'),
        state: BangumiProgressState.watching,
      ),
    );
    expect(syncResult, isA<AcgProviderSuccess<void>>());
    final AcgProviderResult<void> subjectSync =
        await authenticated.syncSubjectCollection(
      const BangumiSubjectCollectionUpdate(
        subjectId: BangumiSubjectId('subject-1017'),
        status: BangumiSubjectCollectionStatus.dropped,
      ),
    );
    expect(subjectSync, isA<AcgProviderSuccess<void>>());

    final AcgProviderResult<List<BangumiAnimeCollectionItem>> collectionResult =
        await authenticated.currentAnimeCollection();
    final List<BangumiAnimeCollectionItem> collection = (collectionResult
            as AcgProviderSuccess<List<BangumiAnimeCollectionItem>>)
        .value;
    expect(collection.single.title, 'Elaina');
    expect(collection.single.status, BangumiSubjectCollectionStatus.watching);

    final BangumiProviderRuntime unauthenticated = BangumiProviderRuntime(
      gateway: RecordingProviderGateway(),
      now: () => now,
    );
    final AcgProviderResult<BangumiAuthSession> missingSession =
        await unauthenticated.currentSession();
    expect((missingSession as AcgProviderFailure<BangumiAuthSession>).kind,
        AcgProviderFailureKind.unauthenticated);
    final AcgProviderResult<void> missingSync =
        await unauthenticated.syncProgress(
      const BangumiProgressUpdate(
        subjectId: BangumiSubjectId('subject-1017'),
        episodeId: BangumiEpisodeId('episode-1'),
        state: BangumiProgressState.completed,
      ),
    );
    expect((missingSync as AcgProviderFailure<void>).kind,
        AcgProviderFailureKind.unauthenticated);
    final AcgProviderResult<void> missingSubjectSync =
        await unauthenticated.syncSubjectCollection(
      const BangumiSubjectCollectionUpdate(
        subjectId: BangumiSubjectId('subject-1017'),
        status: BangumiSubjectCollectionStatus.watching,
      ),
    );
    expect((missingSubjectSync as AcgProviderFailure<void>).kind,
        AcgProviderFailureKind.unauthenticated);
    final AcgProviderResult<List<BangumiAnimeCollectionItem>>
        missingCollection = await unauthenticated.currentAnimeCollection();
    expect(
        (missingCollection
                as AcgProviderFailure<List<BangumiAnimeCollectionItem>>)
            .kind,
        AcgProviderFailureKind.unauthenticated);

    authenticated.dispose();
    final AcgProviderResult<BangumiSubject> disposedLookup = await authenticated
        .lookupSubject(const BangumiSubjectId('subject-1017'));
    expect((disposedLookup as AcgProviderFailure<BangumiSubject>).kind,
        AcgProviderFailureKind.unavailable);
  });

  test(
      'domain bootstrap routes Bangumi through runtime and leaves Dandanplay optional',
      () async {
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-2'),
      title: 'Optional Enrichment',
    );
    final BangumiAcgRuntime runtime = BangumiAcgRuntime(
      gateway: RecordingProviderGateway(),
      subjects: <BangumiSubject>[subject],
    );

    final AcgProviderResult<BangumiSubject> bangumi =
        await runtime.controller.bangumiSubject(subject.id);
    expect((bangumi as AcgProviderSuccess<BangumiSubject>).value.title,
        'Optional Enrichment');

    final AcgProviderResult<List<DandanplayMatchCandidate>> dandanplay =
        await runtime.controller.matchDandanplay('local-file.mkv');
    expect(
        (dandanplay as AcgProviderFailure<List<DandanplayMatchCandidate>>).kind,
        AcgProviderFailureKind.unavailable);
  });

  test('disposed runtime rejects direct gateway execution without dispatch',
      () async {
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final BangumiProviderRuntime runtime = BangumiProviderRuntime(
      gateway: gateway,
    );
    bool loaderExecuted = false;

    runtime.dispose();

    await expectLater(
      runtime.executeGatewayRequest<String>(
        cacheKey: 'direct-after-dispose',
        load: () async {
          loaderExecuted = true;
          return 'should-not-run';
        },
      ),
      throwsA(
        isA<ProviderFailure>()
            .having(
              (ProviderFailure failure) => failure.kind,
              'kind',
              ProviderFailureKind.terminal,
            )
            .having(
              (ProviderFailure failure) => failure.message,
              'message',
              'Bangumi provider runtime has been disposed.',
            ),
      ),
    );

    expect(loaderExecuted, isFalse);
    expect(gateway.registeredProviderId, isNull);
    expect(gateway.lastCacheKey, isNull);
  });

  test('concrete API provider maps metadata requests through gateway',
      () async {
    final RecordingProviderGateway gateway =
        RecordingProviderGateway(proxyUrl: 'http://127.0.0.1:7890');
    final FakeBangumiTransport transport = FakeBangumiTransport(
      responses: <String, BangumiApiResponse>{
        'GET /v0/subjects/42': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"id":42,"name":"Fallback","name_cn":"Concrete Title","summary":"From API"}',
        ),
        'POST /v0/search/subjects?limit=20&offset=0': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"data":[{"id":43,"name":"Search Fallback","name_cn":"Search Title","summary":"Hit"}]}',
        ),
        'POST /v0/search/subjects?limit=7&offset=0': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"total":1,"limit":7,"offset":0,"data":[{"id":44,"type":2,"name":"Recent Hot Anime","name_cn":"","short_summary":"Popular","images":{"common":"https://img.test/recent-hot-common.jpg","large":"https://img.test/recent-hot.jpg"},"eps":12,"score":9.3,"rank":1,"collection_total":120000}]}',
        ),
        'POST /v0/search/subjects?limit=24&offset=24': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"total":48,"limit":24,"offset":24,"data":[{"id":45,"type":2,"name":"Recent Six Month Anime","name_cn":"","short_summary":"Recent","images":{"common":"https://img.test/recent-six-month.jpg"},"eps":13,"rating":{"score":8.4,"rank":120},"collection":{"wish":1000,"collect":2000,"doing":300,"on_hold":40,"dropped":5}}]}',
        ),
        'GET /v0/episodes/7': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"id":7,"subject_id":42,"ep":1,"name":"Episode Fallback","name_cn":"Episode Title"}',
        ),
        'GET /v0/episodes?subject_id=42&limit=200&offset=0':
            const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"total":2,"limit":200,"offset":0,"data":[{"id":8,"subject_id":42,"ep":2,"name":"Episode Two","name_cn":""},{"id":7,"subject_id":42,"ep":1,"name":"Episode One","name_cn":"第一话"}]}',
        ),
        'GET /v0/subjects/42/persons': const BangumiApiResponse(
          statusCode: 200,
          body:
              '[{"id":1001,"name":"Director Name","relation":"导演","career":["producer","director"],"eps":"1-12","images":{"large":"https://img.test/person-large.jpg"}}]',
        ),
        'GET /v0/subjects/42/characters': const BangumiApiResponse(
          statusCode: 200,
          body:
              '[{"id":2001,"name":"Heroine","relation":"主角","summary":"Character summary","images":{"medium":"https://img.test/character-medium.jpg"},"actors":[{"id":3001,"name":"Voice Actor","career":["seiyu"],"images":{"small":"https://img.test/actor-small.jpg"}}]}]',
        ),
        'GET /v0/subjects/42/subjects': const BangumiApiResponse(
          statusCode: 200,
          body:
              '[{"id":4001,"name":"Related Fallback","name_cn":"Related Title","relation":"续集","type":2,"images":{"common":"https://img.test/related-common.jpg"}}]',
        ),
      },
    );
    final BangumiApiProvider provider = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      now: () => DateTime.utc(2026, 6, 21),
    );
    final BangumiProviderRuntime runtime = BangumiProviderRuntime(
      gateway: gateway,
      metadataProvider: provider,
      authProvider: provider,
    );

    final AcgProviderResult<BangumiSubject> subject =
        await runtime.lookupSubject(const BangumiSubjectId('42'));
    expect((subject as AcgProviderSuccess<BangumiSubject>).value.title,
        'Concrete Title');
    expect(gateway.registeredProviderId, bangumiProviderId.value);
    expect(gateway.lastCacheKey, 'subject:42');
    expect(gateway.lastNetworkPolicyUri,
        Uri.parse('https://api.test/v0/subjects/42'));
    expect(transport.requests.single.method, 'GET');
    expect(transport.requests.single.uri.path, '/v0/subjects/42');
    expect(transport.requests.single.proxyUrl, 'http://127.0.0.1:7890');
    expect(
      transport.requests.single.headers['user-agent'],
      defaultBangumiApiUserAgent,
    );
    expect(defaultBangumiApiUserAgent, contains('ppx007/Elaina'));
    expect(defaultBangumiApiUserAgent, contains('github.com/ppx007/Elaina'));

    final AcgProviderResult<List<BangumiSubject>> search =
        await runtime.searchSubjects(' concrete ');
    final BangumiApiRequest searchRequest = transport.requests.last;
    expect(gateway.lastCacheKey, 'subject-search:concrete');
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://api.test/v0/search/subjects?limit=20&offset=0'),
    );
    expect(searchRequest.method, 'POST');
    expect(searchRequest.uri.path, '/v0/search/subjects');
    expect(searchRequest.uri.queryParameters['limit'], '20');
    final Map<String, Object?> searchBody =
        jsonDecode(searchRequest.body!) as Map<String, Object?>;
    expect(searchBody['keyword'], 'concrete');
    expect(
      ((search as AcgProviderSuccess<List<BangumiSubject>>).value)
          .single
          .id
          .value,
      '43',
    );

    final AcgProviderResult<List<BangumiSubject>> popular =
        await runtime.popularAnime();
    final BangumiApiRequest popularRequest = transport.requests.last;
    expect(gateway.lastCacheKey, 'subject-popular-anime:20260621');
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://api.test/v0/search/subjects?limit=7&offset=0'),
    );
    expect(popularRequest.method, 'POST');
    expect(popularRequest.uri.path, '/v0/search/subjects');
    expect(popularRequest.uri.queryParameters['limit'], '7');
    expect(popularRequest.uri.queryParameters['offset'], '0');
    final Map<String, Object?> popularBody =
        jsonDecode(popularRequest.body!) as Map<String, Object?>;
    expect(popularBody['sort'], 'heat');
    final Map<String, Object?> popularFilter =
        popularBody['filter'] as Map<String, Object?>;
    expect(
      (popularFilter['type'] as List<Object?>).single,
      bangumiAnimeSubjectType,
    );
    expect(
      popularFilter['air_date'],
      <String>['>=2026-05-23', '<2026-06-22'],
    );
    final BangumiSubject popularSubject =
        (popular as AcgProviderSuccess<List<BangumiSubject>>).value.single;
    expect(popularSubject.title, 'Recent Hot Anime');
    expect(popularSubject.summary, 'Popular');
    expect(
        popularSubject.coverUri, Uri.parse('https://img.test/recent-hot.jpg'));
    expect(popularSubject.rank, 1);
    expect(popularSubject.score, 9.3);
    expect(popularSubject.collectionTotal, 120000);
    expect(popularSubject.episodeCount, 12);

    final AcgProviderResult<List<BangumiSubject>> recentPopular =
        await runtime.recentPopularAnime(
      now: DateTime.utc(2026, 6, 21),
      limit: 24,
      offset: 24,
    );
    final BangumiApiRequest recentPopularRequest = transport.requests.last;
    expect(
      gateway.lastCacheKey,
      'subject-recent-popular-anime:20260621:24:24',
    );
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://api.test/v0/search/subjects?limit=24&offset=24'),
    );
    expect(recentPopularRequest.method, 'POST');
    expect(recentPopularRequest.uri.path, '/v0/search/subjects');
    final Map<String, Object?> recentPopularBody =
        jsonDecode(recentPopularRequest.body!) as Map<String, Object?>;
    expect(recentPopularBody['sort'], 'heat');
    final Map<String, Object?> recentPopularFilter =
        recentPopularBody['filter'] as Map<String, Object?>;
    expect(
      recentPopularFilter['air_date'],
      <String>['>=2025-12-21', '<2026-06-22'],
    );
    final BangumiSubject recentPopularSubject =
        (recentPopular as AcgProviderSuccess<List<BangumiSubject>>)
            .value
            .single;
    expect(recentPopularSubject.title, 'Recent Six Month Anime');
    expect(recentPopularSubject.rank, 120);
    expect(recentPopularSubject.score, 8.4);
    expect(recentPopularSubject.collectionTotal, 3345);
    expect(
      recentPopularSubject.coverUri,
      Uri.parse('https://img.test/recent-six-month.jpg'),
    );

    final AcgProviderResult<BangumiEpisode> episode =
        await runtime.lookupEpisode(const BangumiEpisodeId('7'));
    final BangumiEpisode mapped =
        (episode as AcgProviderSuccess<BangumiEpisode>).value;
    expect(mapped.subjectId.value, '42');
    expect(mapped.index, 1);
    expect(mapped.title, 'Episode Title');
    expect(gateway.lastNetworkPolicyUri,
        Uri.parse('https://api.test/v0/episodes/7'));

    final AcgProviderResult<List<BangumiEpisode>> listed =
        await runtime.listEpisodes(const BangumiSubjectId('42'));
    final List<BangumiEpisode> listedEpisodes =
        (listed as AcgProviderSuccess<List<BangumiEpisode>>).value;
    expect(gateway.lastCacheKey, 'episodes:42');
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse(
          'https://api.test/v0/episodes?subject_id=42&limit=200&offset=0'),
    );
    expect(
      listedEpisodes.map((BangumiEpisode episode) => episode.title),
      <String>['第一话', 'Episode Two'],
    );

    final AcgProviderResult<List<BangumiRelatedPerson>> persons =
        await runtime.listSubjectPersons(const BangumiSubjectId('42'));
    final BangumiRelatedPerson person =
        (persons as AcgProviderSuccess<List<BangumiRelatedPerson>>)
            .value
            .single;
    expect(gateway.lastCacheKey, 'subject-persons:42');
    expect(gateway.lastNetworkPolicyUri,
        Uri.parse('https://api.test/v0/subjects/42/persons'));
    expect(transport.requests.last.proxyUrl, 'http://127.0.0.1:7890');
    expect(person.id.value, '1001');
    expect(person.name, 'Director Name');
    expect(person.relation, '导演');
    expect(person.careers, <String>['producer', 'director']);
    expect(person.episodeRange, '1-12');
    expect(person.imageUri, Uri.parse('https://img.test/person-large.jpg'));

    final AcgProviderResult<List<BangumiRelatedCharacter>> characters =
        await runtime.listSubjectCharacters(const BangumiSubjectId('42'));
    final BangumiRelatedCharacter character =
        (characters as AcgProviderSuccess<List<BangumiRelatedCharacter>>)
            .value
            .single;
    expect(gateway.lastCacheKey, 'subject-characters:42');
    expect(gateway.lastNetworkPolicyUri,
        Uri.parse('https://api.test/v0/subjects/42/characters'));
    expect(character.name, 'Heroine');
    expect(character.relation, '主角');
    expect(character.summary, 'Character summary');
    expect(
      character.imageUri,
      Uri.parse('https://img.test/character-medium.jpg'),
    );
    expect(character.actors.single.name, 'Voice Actor');
    expect(character.actors.single.careers, <String>['seiyu']);
    expect(
      character.actors.single.imageUri,
      Uri.parse('https://img.test/actor-small.jpg'),
    );

    final AcgProviderResult<List<BangumiRelatedSubject>> relations =
        await runtime.listSubjectRelations(const BangumiSubjectId('42'));
    final BangumiRelatedSubject relation =
        (relations as AcgProviderSuccess<List<BangumiRelatedSubject>>)
            .value
            .single;
    expect(gateway.lastCacheKey, 'subject-relations:42');
    expect(gateway.lastNetworkPolicyUri,
        Uri.parse('https://api.test/v0/subjects/42/subjects'));
    expect(relation.id.value, '4001');
    expect(relation.title, 'Related Title');
    expect(relation.relation, '续集');
    expect(relation.type, bangumiAnimeSubjectType);
    expect(
      relation.coverUri,
      Uri.parse('https://img.test/related-common.jpg'),
    );
  });

  test('concrete API client exposes Bangumi token acquisition URI', () {
    final BangumiApiClient client = BangumiApiClient(
      transport:
          FakeBangumiTransport(responses: const <String, BangumiApiResponse>{}),
      baseUri: Uri.parse('https://api.test'),
    );

    final Uri uri = client.accessTokenPageUri();

    expect(uri.scheme, 'https');
    expect(uri.host, 'next.bgm.tv');
    expect(uri.path, '/demo/access-token');
  });

  test('concrete API provider uses Bangumi mirror API and image rewrite',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 21);
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final FakeBangumiTransport transport = FakeBangumiTransport(
      responses: <String, BangumiApiResponse>{
        'GET /api/v0/subjects/42': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"id":42,"name":"Mirror","name_cn":"Mirror Title","images":{"large":"https://lain.bgm.tv/pic/cover/l/42.jpg"}}',
        ),
        'POST /api/v0/search/subjects?limit=20&offset=0':
            const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"data":[{"id":43,"name":"External Image","images":{"large":"https://img.test/not-bangumi.jpg"}}]}',
        ),
        'GET /api/v0/me': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"username":"alice","nickname":"Alice","avatar":{"large":"https://lain.bgm.tv/pic/user/l/1.jpg"}}',
        ),
      },
    );
    final BangumiApiProvider provider = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        mirrorConfigProvider: () async => BangumiApiMirrorConfig.enabled(
          apiBaseUri: Uri.parse('https://mirror.test/api'),
          imageBaseUri: Uri.parse('https://mirror.test/image'),
        ),
      ),
      accessTokenProvider: () async => BangumiApiAccessToken(
        value: 'token-1',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      now: () => now,
    );

    final AcgProviderResult<BangumiSubject> subject =
        await provider.lookupSubject(const BangumiSubjectId('42'));
    final BangumiSubject mappedSubject =
        (subject as AcgProviderSuccess<BangumiSubject>).value;
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://mirror.test/api/v0/subjects/42'),
    );
    expect(transport.requests.single.uri.host, 'mirror.test');
    expect(transport.requests.single.uri.path, '/api/v0/subjects/42');
    expect(
      mappedSubject.coverUri,
      Uri.https('mirror.test', '/image', <String, String>{
        bangumiMirrorImageUrlParameter:
            'https://lain.bgm.tv/pic/cover/l/42.jpg',
      }),
    );

    final AcgProviderResult<List<BangumiSubject>> search =
        await provider.searchSubjects('external');
    final BangumiSubject searchItem =
        (search as AcgProviderSuccess<List<BangumiSubject>>).value.single;
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://mirror.test/api/v0/search/subjects?limit=20&offset=0'),
    );
    expect(searchItem.coverUri, Uri.parse('https://img.test/not-bangumi.jpg'));

    final AcgProviderResult<BangumiAuthSession> session =
        await provider.currentSession();
    final BangumiAuthSession mappedSession =
        (session as AcgProviderSuccess<BangumiAuthSession>).value;
    expect(transport.requests.last.headers['authorization'], 'Bearer token-1');
    expect(
      mappedSession.avatarUri,
      Uri.https('mirror.test', '/image', <String, String>{
        bangumiMirrorImageUrlParameter: 'https://lain.bgm.tv/pic/user/l/1.jpg',
      }),
    );
  });

  test('invalid Bangumi mirror config fails before dispatch', () async {
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final FakeBangumiTransport transport = FakeBangumiTransport(
      responses: const <String, BangumiApiResponse>{},
    );
    final BangumiApiProvider provider = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        mirrorConfigProvider: () async => BangumiApiMirrorConfig.enabled(
          apiBaseUri: Uri.parse('file:///api'),
          imageBaseUri: Uri.parse('https://mirror.test/image?bad=1'),
        ),
      ),
    );

    final AcgProviderResult<BangumiSubject> result =
        await provider.lookupSubject(const BangumiSubjectId('42'));

    expect((result as AcgProviderFailure<BangumiSubject>).kind,
        AcgProviderFailureKind.terminal);
    expect(result.message, contains('Bangumi mirror configuration is invalid'));
    expect(gateway.lastCacheKey, isNull);
    expect(transport.requests, isEmpty);
  });

  test('concrete API provider maps auth and progress with bearer token',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 16);
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final FakeBangumiTransport transport = FakeBangumiTransport(
      responses: <String, BangumiApiResponse>{
        'GET /v0/me': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"username":"alice","nickname":"Alice","avatar":{"large":"https://img.test/alice-large.jpg","medium":"https://img.test/alice-medium.jpg"}}',
        ),
        'PUT /v0/users/-/collections/-/episodes/7':
            const BangumiApiResponse(statusCode: 204, body: ''),
        'PUT /v0/users/-/collections/-/episodes/8':
            const BangumiApiResponse(statusCode: 204, body: ''),
        'POST /v0/users/-/collections/42':
            const BangumiApiResponse(statusCode: 204, body: ''),
        'GET /v0/users/alice/collections?subject_type=2&limit=50&offset=0':
            const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"total":1,"limit":50,"offset":0,"data":[{"subject_id":42,"subject_type":2,"type":3,"ep_status":5,"updated_at":"2026-06-20T12:00:00+08:00","subject":{"id":42,"type":2,"name":"Fallback","name_cn":"Tracking Title","eps":12,"images":{"large":"https://img.test/cover.jpg"}}}]}',
        ),
      },
    );
    final BangumiApiProvider provider = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      accessTokenProvider: () async => BangumiApiAccessToken(
        value: 'token-1',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      now: () => now,
    );

    final AcgProviderResult<BangumiAuthSession> session =
        await provider.currentSession();
    final BangumiAuthSession mappedSession =
        (session as AcgProviderSuccess<BangumiAuthSession>).value;
    expect(mappedSession.userId, 'alice');
    expect(mappedSession.displayName, 'Alice');
    expect(
      mappedSession.avatarUri,
      Uri.parse('https://img.test/alice-large.jpg'),
    );
    expect(gateway.lastCacheKey, 'auth-session:current');
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkOnly);
    expect(gateway.lastDeduplicationWindow, Duration.zero);
    expect(gateway.lastNetworkPolicyUri, Uri.parse('https://api.test/v0/me'));
    expect(
      transport.requests.single.headers['authorization'],
      'Bearer token-1',
    );

    final AcgProviderResult<void> progress = await provider.syncProgress(
      const BangumiProgressUpdate(
        subjectId: BangumiSubjectId('42'),
        episodeId: BangumiEpisodeId('7'),
        state: BangumiProgressState.completed,
      ),
    );
    expect(progress, isA<AcgProviderSuccess<void>>());
    expect(gateway.lastCacheKey, 'progress:42:7:completed');
    final Map<String, Object?> body =
        jsonDecode(transport.requests.last.body!) as Map<String, Object?>;
    expect(body['type'], bangumiEpisodeCollectionDone);

    // On-hold must never be sent as "dropped" (destructive); it maps to wish.
    final AcgProviderResult<void> onHold = await provider.syncProgress(
      const BangumiProgressUpdate(
        subjectId: BangumiSubjectId('42'),
        episodeId: BangumiEpisodeId('8'),
        state: BangumiProgressState.onHold,
      ),
    );
    expect(onHold, isA<AcgProviderSuccess<void>>());
    final Map<String, Object?> onHoldBody =
        jsonDecode(transport.requests.last.body!) as Map<String, Object?>;
    expect(onHoldBody['type'], bangumiEpisodeCollectionWish);
    expect(onHoldBody['type'], isNot(bangumiEpisodeCollectionDropped));

    final AcgProviderResult<void> subjectCollection =
        await provider.syncSubjectCollection(
      const BangumiSubjectCollectionUpdate(
        subjectId: BangumiSubjectId('42'),
        status: BangumiSubjectCollectionStatus.dropped,
      ),
    );
    expect(subjectCollection, isA<AcgProviderSuccess<void>>());
    expect(gateway.lastCacheKey, 'subject-collection:42:dropped');
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://api.test/v0/users/-/collections/42'),
    );
    final BangumiApiRequest subjectCollectionRequest = transport.requests.last;
    expect(subjectCollectionRequest.method, 'POST');
    expect(subjectCollectionRequest.uri.path, '/v0/users/-/collections/42');
    expect(
      subjectCollectionRequest.headers['authorization'],
      'Bearer token-1',
    );
    final Map<String, Object?> subjectCollectionBody =
        jsonDecode(subjectCollectionRequest.body!) as Map<String, Object?>;
    expect(subjectCollectionBody['type'], bangumiSubjectCollectionDropped);

    final AcgProviderResult<List<BangumiAnimeCollectionItem>> collection =
        await provider.currentAnimeCollection();
    final BangumiAnimeCollectionItem item =
        (collection as AcgProviderSuccess<List<BangumiAnimeCollectionItem>>)
            .value
            .single;
    expect(gateway.lastCacheKey, 'anime-collection:current');
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkOnly);
    expect(gateway.lastDeduplicationWindow, Duration.zero);
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse(
          'https://api.test/v0/users/-/collections?subject_type=2&limit=50&offset=0'),
    );
    expect(transport.requests.last.method, 'GET');
    expect(transport.requests.last.uri.path, '/v0/users/alice/collections');
    expect(transport.requests.last.headers['authorization'], 'Bearer token-1');
    expect(item.subjectId.value, '42');
    expect(item.title, 'Tracking Title');
    expect(item.status, BangumiSubjectCollectionStatus.watching);
    expect(item.watchedEpisodes, 5);
    expect(item.totalEpisodes, 12);
    expect(item.coverUri, Uri.parse('https://img.test/cover.jpg'));
  });

  test('runtime registers concrete provider before auth requests', () async {
    final DateTime now = DateTime.utc(2026, 6, 20);
    final DeterministicStorageFoundation storage =
        DeterministicStorageFoundation();
    final DeterministicProviderGateway gateway =
        DeterministicProviderGateway(storage: storage);
    final FakeBangumiTransport transport = FakeBangumiTransport(
      responses: <String, BangumiApiResponse>{
        'GET /v0/me': const BangumiApiResponse(
          statusCode: 200,
          body: '{"username":"alice","nickname":"Alice"}',
        ),
        'GET /v0/users/alice/collections?subject_type=2&limit=50&offset=0':
            const BangumiApiResponse(
          statusCode: 200,
          body: '{"total":0,"limit":50,"offset":0,"data":[]}',
        ),
      },
    );
    final BangumiApiProvider provider = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      accessTokenProvider: () async => BangumiApiAccessToken(
        value: 'token-1',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      now: () => now,
    );

    final AcgProviderResult<BangumiAuthSession> direct =
        await provider.currentSession();
    expect((direct as AcgProviderFailure<BangumiAuthSession>).message,
        contains('Provider bangumi is not registered'));
    final AcgProviderResult<List<BangumiAnimeCollectionItem>> directCollection =
        await provider.currentAnimeCollection();
    expect(
      (directCollection as AcgProviderFailure<List<BangumiAnimeCollectionItem>>)
          .message,
      contains('Provider bangumi is not registered'),
    );

    final BangumiProviderRuntime runtime = BangumiProviderRuntime(
      gateway: gateway,
      metadataProvider: provider,
      authProvider: provider,
      collectionProvider: provider,
    );
    final AcgProviderResult<BangumiAuthSession> viaRuntime =
        await runtime.currentSession();

    final BangumiAuthSession session =
        (viaRuntime as AcgProviderSuccess<BangumiAuthSession>).value;
    expect(session.userId, 'alice');

    final AcgProviderResult<List<BangumiAnimeCollectionItem>>
        viaRuntimeCollection = await runtime.currentAnimeCollection();
    expect(
      (viaRuntimeCollection
              as AcgProviderSuccess<List<BangumiAnimeCollectionItem>>)
          .value,
      isEmpty,
    );
  });

  test('concrete API provider normalizes auth and API failures', () async {
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final FakeBangumiTransport transport = FakeBangumiTransport(
      responses: <String, BangumiApiResponse>{
        'GET /v0/subjects/missing':
            const BangumiApiResponse(statusCode: 404, body: '{"title":"no"}'),
        'GET /v0/subjects/throttled':
            const BangumiApiResponse(statusCode: 429, body: '{"title":"slow"}'),
        'GET /v0/subjects/bad':
            const BangumiApiResponse(statusCode: 200, body: '{bad'),
        'GET /v0/subjects/missing/persons':
            const BangumiApiResponse(statusCode: 404, body: '{"title":"no"}'),
        'GET /v0/subjects/throttled/characters':
            const BangumiApiResponse(statusCode: 429, body: '{"title":"slow"}'),
        'GET /v0/subjects/bad/subjects':
            const BangumiApiResponse(statusCode: 200, body: '{bad'),
        'GET /v0/me':
            const BangumiApiResponse(statusCode: 401, body: '{"title":"auth"}'),
      },
    );
    final BangumiApiProvider unauthenticated = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
    );

    final AcgProviderResult<void> noTokenProgress =
        await unauthenticated.syncProgress(
      const BangumiProgressUpdate(
        subjectId: BangumiSubjectId('42'),
        episodeId: BangumiEpisodeId('7'),
        state: BangumiProgressState.completed,
      ),
    );
    expect((noTokenProgress as AcgProviderFailure<void>).kind,
        AcgProviderFailureKind.unauthenticated);
    final AcgProviderResult<List<BangumiAnimeCollectionItem>>
        noTokenCollection = await unauthenticated.currentAnimeCollection();
    expect(
        (noTokenCollection
                as AcgProviderFailure<List<BangumiAnimeCollectionItem>>)
            .kind,
        AcgProviderFailureKind.unauthenticated);
    expect(transport.requests, isEmpty);

    final AcgProviderResult<BangumiSubject> missing =
        await unauthenticated.lookupSubject(const BangumiSubjectId('missing'));
    expect((missing as AcgProviderFailure<BangumiSubject>).kind,
        AcgProviderFailureKind.cachedMiss);

    final AcgProviderResult<BangumiSubject> throttled = await unauthenticated
        .lookupSubject(const BangumiSubjectId('throttled'));
    expect((throttled as AcgProviderFailure<BangumiSubject>).kind,
        AcgProviderFailureKind.throttled);

    final AcgProviderResult<BangumiSubject> malformed =
        await unauthenticated.lookupSubject(const BangumiSubjectId('bad'));
    expect((malformed as AcgProviderFailure<BangumiSubject>).kind,
        AcgProviderFailureKind.terminal);

    final AcgProviderResult<List<BangumiRelatedPerson>> missingPersons =
        await unauthenticated
            .listSubjectPersons(const BangumiSubjectId('missing'));
    expect(
      (missingPersons as AcgProviderFailure<List<BangumiRelatedPerson>>).kind,
      AcgProviderFailureKind.cachedMiss,
    );

    final AcgProviderResult<List<BangumiRelatedCharacter>> throttledCharacters =
        await unauthenticated
            .listSubjectCharacters(const BangumiSubjectId('throttled'));
    expect(
      (throttledCharacters as AcgProviderFailure<List<BangumiRelatedCharacter>>)
          .kind,
      AcgProviderFailureKind.throttled,
    );

    final AcgProviderResult<List<BangumiRelatedSubject>> malformedRelations =
        await unauthenticated
            .listSubjectRelations(const BangumiSubjectId('bad'));
    expect(
      (malformedRelations as AcgProviderFailure<List<BangumiRelatedSubject>>)
          .kind,
      AcgProviderFailureKind.terminal,
    );

    final BangumiApiProvider invalidToken = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      accessTokenProvider: () async => BangumiApiAccessToken(
        value: 'expired-server-side',
        expiresAt: DateTime.utc(2026, 6, 17),
      ),
      now: () => DateTime.utc(2026, 6, 16),
    );
    final AcgProviderResult<BangumiAuthSession> invalidSession =
        await invalidToken.currentSession();
    expect((invalidSession as AcgProviderFailure<BangumiAuthSession>).kind,
        AcgProviderFailureKind.unauthenticated);
  });

  test(
      'concrete API provider falls back to cached subject on transient detail failure',
      () async {
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final QueuedBangumiTransport transport = QueuedBangumiTransport(
      <Object>[
        const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"total":1,"limit":7,"offset":0,"data":[{"id":44,"type":2,"name":"Cached Hot Anime","name_cn":"","short_summary":"Cached summary","images":{"large":"https://img.test/cached-hot.jpg"},"eps":12}]}',
        ),
        const HandshakeException('Connection terminated during handshake'),
        const BangumiApiResponse(statusCode: 404, body: '{"title":"no"}'),
      ],
    );
    final BangumiApiProvider provider = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
    );
    final BangumiProviderRuntime runtime = BangumiProviderRuntime(
      gateway: gateway,
      metadataProvider: provider,
      discoveryProvider: provider,
    );

    final AcgProviderResult<List<BangumiSubject>> popular =
        await runtime.popularAnime();
    expect(popular, isA<AcgProviderSuccess<List<BangumiSubject>>>());

    final AcgProviderResult<BangumiSubject> transientDetail =
        await runtime.lookupSubject(const BangumiSubjectId('44'));
    final BangumiSubject cached =
        (transientDetail as AcgProviderSuccess<BangumiSubject>).value;
    expect(cached.title, 'Cached Hot Anime');
    expect(cached.summary, 'Cached summary');
    expect(cached.coverUri, Uri.parse('https://img.test/cached-hot.jpg'));
    expect(transport.requests.last.uri.path, '/v0/subjects/44');

    final AcgProviderResult<BangumiSubject> notFoundDetail =
        await runtime.lookupSubject(const BangumiSubjectId('44'));
    expect(
      (notFoundDetail as AcgProviderFailure<BangumiSubject>).kind,
      AcgProviderFailureKind.cachedMiss,
    );
  });
}
