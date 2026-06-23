// Bangumi runtime tests intentionally exercise gateway routing, cache policy,
// mirror rewriting, and JSON mapping together because those bugs appear at the
// provider boundary rather than inside isolated model constructors.
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
    final ProviderRequestKey trendingKey = bangumiTrendingAnimeRequestKey(
      now: DateTime.utc(2026, 6, 21),
      limit: 24,
      offset: 48,
    );
    final ProviderRequestKey recentPopularKey =
        bangumiRecentPopularAnimeRequestKey(
      now: DateTime.utc(2026, 6, 21),
      limit: 20,
      offset: 40,
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
    expect(episodeKey.cacheKey, 'episode:7');
    expect(episodeListKey.cacheKey, 'episodes:42');
    expect(
      trendingKey.cacheKey,
      'subject-trending-anime:30d:20260621:24:48',
    );
    expect(
      recentPopularKey.cacheKey,
      'subject-recent-popular-anime:90d:20260621:20:40',
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
        'POST /v0/search/subjects?limit=20&offset=20': const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"data":[{"id":46,"name":"Recent Popular Fallback","name_cn":"Recent Popular Title","summary":"Recent API"}]}',
        ),
        'GET /anime/browser/?sort=trends': const BangumiApiResponse(
          statusCode: 200,
          body: _trendsPageOneHtml,
        ),
        'GET /anime/browser/?sort=trends&page=2': const BangumiApiResponse(
          statusCode: 200,
          body: _trendsPageTwoHtml,
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

    final AcgProviderResult<List<BangumiSubject>> trendingHero =
        await runtime.trendingAnime(limit: 7, offset: 0);
    final BangumiApiRequest trendingHeroRequest = transport.requests.last;
    expect(
      gateway.lastCacheKey,
      'subject-trending-anime:30d:20260621:7:0',
    );
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://bgm.tv/anime/browser/?sort=trends'),
    );
    expect(trendingHeroRequest.method, 'GET');
    expect(trendingHeroRequest.uri.path, '/anime/browser/');
    expect(trendingHeroRequest.uri.queryParameters['sort'], 'trends');
    expect(
        trendingHeroRequest.uri.queryParameters.containsKey('page'), isFalse);
    expect(trendingHeroRequest.body, isNull);
    expect(trendingHeroRequest.headers['accept'], contains('text/html'));
    expect(trendingHeroRequest.proxyUrl, 'http://127.0.0.1:7890');
    final List<BangumiSubject> trendingHeroSubjects =
        (trendingHero as AcgProviderSuccess<List<BangumiSubject>>).value;
    final BangumiSubject popularSubject = trendingHeroSubjects.first;
    expect(trendingHeroSubjects, hasLength(7));
    expect(popularSubject.id.value, '44');
    expect(popularSubject.title, 'Future Official Trends Anime');
    expect(popularSubject.summary, contains('2026年7月9日'));
    expect(
      popularSubject.coverUri,
      Uri.parse('https://lain.bgm.tv/r/400/pic/cover/l/aa/bb/44.jpg'),
    );
    expect(popularSubject.rank, 1827);
    expect(popularSubject.score, 7.2);
    expect(popularSubject.collectionTotal, 120000);
    expect(popularSubject.episodeCount, 12);

    final AcgProviderResult<List<BangumiSubject>> trendingPageTwo =
        await runtime.trendingAnime(
      limit: 24,
      offset: 24,
    );
    final BangumiApiRequest trendingPageTwoRequest = transport.requests.last;
    expect(
      gateway.lastCacheKey,
      'subject-trending-anime:30d:20260621:24:24',
    );
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://bgm.tv/anime/browser/?sort=trends&page=2'),
    );
    expect(trendingPageTwoRequest.method, 'GET');
    expect(trendingPageTwoRequest.uri.path, '/anime/browser/');
    expect(trendingPageTwoRequest.uri.queryParameters['page'], '2');
    final BangumiSubject trendingPageTwoSubject =
        (trendingPageTwo as AcgProviderSuccess<List<BangumiSubject>>)
            .value
            .single;
    expect(trendingPageTwoSubject.title, 'Official Trends Page Two Anime');
    expect(trendingPageTwoSubject.rank, 120);
    expect(trendingPageTwoSubject.score, 8.4);
    expect(trendingPageTwoSubject.collectionTotal, 3345);
    expect(
      trendingPageTwoSubject.coverUri,
      Uri.parse('https://lain.bgm.tv/r/400/pic/cover/l/cc/dd/45.jpg'),
    );

    final AcgProviderResult<List<BangumiSubject>> recentPopular =
        await runtime.recentPopularAnime(limit: 20, offset: 20);
    final BangumiApiRequest recentPopularRequest = transport.requests.last;
    expect(
      gateway.lastCacheKey,
      'subject-recent-popular-anime:90d:20260621:20:20',
    );
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://api.test/v0/search/subjects?limit=20&offset=20'),
    );
    expect(recentPopularRequest.method, 'POST');
    expect(recentPopularRequest.uri.path, '/v0/search/subjects');
    expect(recentPopularRequest.uri.queryParameters['limit'], '20');
    expect(recentPopularRequest.uri.queryParameters['offset'], '20');
    expect(recentPopularRequest.proxyUrl, 'http://127.0.0.1:7890');
    final Map<String, Object?> recentPopularBody =
        jsonDecode(recentPopularRequest.body!) as Map<String, Object?>;
    expect(recentPopularBody['sort'], 'heat');
    final Map<String, Object?> recentPopularFilter =
        recentPopularBody['filter']! as Map<String, Object?>;
    expect(recentPopularFilter['type'], <int>[bangumiAnimeSubjectType]);
    expect(
      recentPopularFilter['air_date'],
      <String>['>=2026-03-24', '<2026-06-22'],
    );
    expect(
      (recentPopular as AcgProviderSuccess<List<BangumiSubject>>)
          .value
          .single
          .title,
      'Recent Popular Title',
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

  test('concrete API provider fails trends parsing without search fallback',
      () async {
    final RecordingProviderGateway gateway = RecordingProviderGateway();
    final FakeBangumiTransport transport = FakeBangumiTransport(
      responses: <String, BangumiApiResponse>{
        'GET /anime/browser/?sort=trends': const BangumiApiResponse(
          statusCode: 200,
          body: '<html><body><p>No subject list</p></body></html>',
        ),
      },
    );
    final BangumiApiProvider provider = BangumiApiProvider(
      gateway: gateway,
      client: BangumiApiClient(transport: transport),
      now: () => DateTime.utc(2026, 6, 21),
    );
    final BangumiProviderRuntime runtime = BangumiProviderRuntime(
      gateway: gateway,
      metadataProvider: provider,
      discoveryProvider: provider,
    );

    final AcgProviderResult<List<BangumiSubject>> result =
        await runtime.trendingAnime(limit: 7, offset: 0);

    expect(
      (result as AcgProviderFailure<List<BangumiSubject>>).kind,
      AcgProviderFailureKind.terminal,
    );
    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.uri.path, '/anime/browser/');
  });

  test('concrete API client exposes Bangumi OAuth authorization URI', () {
    final BangumiApiClient client = BangumiApiClient(
      transport:
          FakeBangumiTransport(responses: const <String, BangumiApiResponse>{}),
      baseUri: Uri.parse('https://api.test'),
    );

    final Uri uri = client.oauthAuthorizationPageUri();

    expect(uri.scheme, 'https');
    expect(uri.host, 'bgm.tv');
    expect(uri.path, '/oauth/authorize');
    expect(uri.queryParameters['client_id'], defaultBangumiOAuthClientId);
    expect(
      uri.queryParameters['response_type'],
      bangumiOAuthAuthorizationResponseType,
    );
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
        'GET /anime/browser/?sort=trends': const BangumiApiResponse(
          statusCode: 200,
          body: _trendsPageOneHtml,
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

    final AcgProviderResult<List<BangumiSubject>> trends =
        await provider.trendingAnime(limit: 7, offset: 0);
    final BangumiSubject trendItem =
        (trends as AcgProviderSuccess<List<BangumiSubject>>).value.first;
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://bgm.tv/anime/browser/?sort=trends'),
    );
    expect(transport.requests.last.uri.host, 'bgm.tv');
    expect(
      trendItem.coverUri,
      Uri.https('mirror.test', '/image', <String, String>{
        bangumiMirrorImageUrlParameter:
            'https://lain.bgm.tv/r/400/pic/cover/l/aa/bb/44.jpg',
      }),
    );

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
          body: _cachedTrendsHtml,
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

    final AcgProviderResult<List<BangumiSubject>> trending =
        await runtime.trendingAnime(limit: 7, offset: 0);
    expect(trending, isA<AcgProviderSuccess<List<BangumiSubject>>>());

    final AcgProviderResult<BangumiSubject> transientDetail =
        await runtime.lookupSubject(const BangumiSubjectId('44'));
    final BangumiSubject cached =
        (transientDetail as AcgProviderSuccess<BangumiSubject>).value;
    expect(cached.title, 'Cached Hot Anime');
    expect(cached.summary, 'Cached summary');
    expect(
      cached.coverUri,
      Uri.parse('https://lain.bgm.tv/r/400/pic/cover/l/ee/ff/44.jpg'),
    );
    expect(transport.requests.last.uri.path, '/v0/subjects/44');

    final AcgProviderResult<BangumiSubject> notFoundDetail =
        await runtime.lookupSubject(const BangumiSubjectId('44'));
    expect(
      (notFoundDetail as AcgProviderFailure<BangumiSubject>).kind,
      AcgProviderFailureKind.cachedMiss,
    );
  });
}

const String _trendsPageOneHtml = '''
<!doctype html>
<html>
  <body>
    <ul id="browserItemList" class="browserFull browser-list">
      <li id="item_44" class="item odd clearit">
        <a href="/subject/44" class="subjectCover cover ll">
          <span class="image">
            <img src="//lain.bgm.tv/r/400/pic/cover/l/aa/bb/44.jpg" class="cover" />
          </span>
        </a>
        <div class="inner">
          <h3><a href="/subject/44" class="l">Future Official Trends Anime</a></h3>
          <span class="rank"><small>Rank </small>1827</span>
          <p class="info tip">12话 / 2026年7月9日 / Official Staff</p>
          <p class="rateInfo">
            <small class="fade">7.2</small>
            <small class="grey">120000 人关注</small>
          </p>
        </div>
      </li>
      <li id="item_46"><h3><a href="/subject/46" class="l">Trend 2</a></h3></li>
      <li id="item_47"><h3><a href="/subject/47" class="l">Trend 3</a></h3></li>
      <li id="item_48"><h3><a href="/subject/48" class="l">Trend 4</a></h3></li>
      <li id="item_49"><h3><a href="/subject/49" class="l">Trend 5</a></h3></li>
      <li id="item_50"><h3><a href="/subject/50" class="l">Trend 6</a></h3></li>
      <li id="item_51"><h3><a href="/subject/51" class="l">Trend 7</a></h3></li>
      <li id="item_52"><h3><a href="/subject/52" class="l">Trend 8</a></h3></li>
    </ul>
  </body>
</html>
''';

const String _trendsPageTwoHtml = '''
<!doctype html>
<html>
  <body>
    <ul id="browserItemList" class="browserFull browser-list">
      <li id="item_45" class="item even clearit">
        <a href="/subject/45" class="subjectCover cover ll">
          <span class="image">
            <img src="//lain.bgm.tv/r/400/pic/cover/l/cc/dd/45.jpg" class="cover" />
          </span>
        </a>
        <div class="inner">
          <h3><a href="/subject/45" class="l">Official Trends Page Two Anime</a></h3>
          <span class="rank"><small>Rank </small>120</span>
          <p class="info tip">13话 / 2026年8月1日 / Page Two Staff</p>
          <p class="rateInfo">
            <small class="fade">8.4</small>
            <small class="grey">3345 人关注</small>
          </p>
        </div>
      </li>
    </ul>
  </body>
</html>
''';

const String _cachedTrendsHtml = '''
<!doctype html>
<html>
  <body>
    <ul id="browserItemList" class="browserFull browser-list">
      <li id="item_44" class="item odd clearit">
        <a href="/subject/44" class="subjectCover cover ll">
          <span class="image">
            <img src="//lain.bgm.tv/r/400/pic/cover/l/ee/ff/44.jpg" class="cover" />
          </span>
        </a>
        <div class="inner">
          <h3><a href="/subject/44" class="l">Cached Hot Anime</a></h3>
          <p class="info tip">Cached summary</p>
        </div>
      </li>
    </ul>
  </body>
</html>
''';
