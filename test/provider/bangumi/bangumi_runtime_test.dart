import 'dart:convert';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'runtime registers policy and looks up subject episode and search results',
      () async {
    final _RecordingGateway gateway = _RecordingGateway();
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
    final ProviderRequestKey collectionKey = bangumiAnimeCollectionRequestKey();
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
    expect(collectionKey.cacheKey, 'anime-collection:current');
    expect(request.cachePolicy, ProviderCachePolicy.networkFirst);
    expect(request.deduplicationWindow, bangumiRuntimeDeduplicationWindow);
  });

  test('gateway failures normalize before reaching domain callers', () async {
    final _FailingGateway gateway =
        _FailingGateway(ProviderFailureKind.throttled);
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
      gateway: _RecordingGateway(),
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

    final AcgProviderResult<List<BangumiAnimeCollectionItem>> collectionResult =
        await authenticated.currentAnimeCollection();
    final List<BangumiAnimeCollectionItem> collection = (collectionResult
            as AcgProviderSuccess<List<BangumiAnimeCollectionItem>>)
        .value;
    expect(collection.single.title, 'Elaina');
    expect(collection.single.status, BangumiSubjectCollectionStatus.watching);

    final BangumiProviderRuntime unauthenticated = BangumiProviderRuntime(
      gateway: _RecordingGateway(),
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
      gateway: _RecordingGateway(),
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
    final _RecordingGateway gateway = _RecordingGateway();
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
    final _RecordingGateway gateway =
        _RecordingGateway(proxyUrl: 'http://127.0.0.1:7890');
    final _FakeBangumiTransport transport = _FakeBangumiTransport(
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
        'GET /v0/subjects?type=2&sort=heat&limit=7&offset=0':
            const BangumiApiResponse(
          statusCode: 200,
          body:
              '{"total":1,"limit":7,"offset":0,"data":[{"id":44,"type":2,"name":"Recent Hot Anime","name_cn":"","short_summary":"Popular","images":{"large":"https://img.test/recent-hot.jpg"},"eps":12,"score":9.3,"rank":1,"collection_total":120000}]}',
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
      },
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
    expect(gateway.lastCacheKey, 'subject-popular-anime');
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse(
          'https://api.test/v0/subjects?type=2&sort=heat&limit=7&offset=0'),
    );
    expect(popularRequest.method, 'GET');
    expect(popularRequest.uri.path, '/v0/subjects');
    expect(popularRequest.uri.queryParameters['sort'], 'heat');
    final BangumiSubject popularSubject =
        (popular as AcgProviderSuccess<List<BangumiSubject>>).value.single;
    expect(popularSubject.title, 'Recent Hot Anime');
    expect(popularSubject.summary, 'Popular');
    expect(popularSubject.rank, 1);
    expect(popularSubject.score, 9.3);
    expect(popularSubject.collectionTotal, 120000);
    expect(popularSubject.episodeCount, 12);

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
  });

  test('concrete API client exposes Bangumi token acquisition URI', () {
    final BangumiApiClient client = BangumiApiClient(
      transport: _FakeBangumiTransport(
          responses: const <String, BangumiApiResponse>{}),
      baseUri: Uri.parse('https://api.test'),
    );

    final Uri uri = client.accessTokenPageUri();

    expect(uri.scheme, 'https');
    expect(uri.host, 'next.bgm.tv');
    expect(uri.path, '/demo/access-token');
  });

  test('concrete API provider maps auth and progress with bearer token',
      () async {
    final DateTime now = DateTime.utc(2026, 6, 16);
    final _RecordingGateway gateway = _RecordingGateway();
    final _FakeBangumiTransport transport = _FakeBangumiTransport(
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
    final _FakeBangumiTransport transport = _FakeBangumiTransport(
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
    final _RecordingGateway gateway = _RecordingGateway();
    final _FakeBangumiTransport transport = _FakeBangumiTransport(
      responses: <String, BangumiApiResponse>{
        'GET /v0/subjects/missing':
            const BangumiApiResponse(statusCode: 404, body: '{"title":"no"}'),
        'GET /v0/subjects/throttled':
            const BangumiApiResponse(statusCode: 429, body: '{"title":"slow"}'),
        'GET /v0/subjects/bad':
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
}

final class _RecordingGateway implements ProviderGateway {
  _RecordingGateway({this.proxyUrl});

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
      ProviderGatewayRequest<T> request) async {
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

final class _FailingGateway implements ProviderGateway {
  _FailingGateway(this.kind);

  final ProviderFailureKind kind;
  final DeterministicStorageFoundation _storage =
      DeterministicStorageFoundation();

  @override
  StorageFoundation get storage => _storage;

  @override
  Future<void> registerProvider(ProviderRegistration registration) async {}

  @override
  Future<ProviderGatewayResponse<T>> execute<T>(
      ProviderGatewayRequest<T> request) {
    return Future<ProviderGatewayResponse<T>>.error(
      ProviderFailure(kind: kind, message: 'Injected gateway failure.'),
    );
  }
}

final class _FakeBangumiTransport implements BangumiApiTransport {
  _FakeBangumiTransport({
    required Map<String, BangumiApiResponse> responses,
  }) : _responses = responses;

  final Map<String, BangumiApiResponse> _responses;
  final List<BangumiApiRequest> requests = <BangumiApiRequest>[];

  @override
  Future<BangumiApiResponse> send(BangumiApiRequest request) async {
    requests.add(request);
    final String key = _requestKey(request);
    final BangumiApiResponse? response = _responses[key];
    if (response != null) return response;
    return const BangumiApiResponse(
      statusCode: 404,
      body: '{"title":"missing fake response"}',
    );
  }

  String _requestKey(BangumiApiRequest request) {
    final String query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    return '${request.method} ${request.uri.path}$query';
  }
}
