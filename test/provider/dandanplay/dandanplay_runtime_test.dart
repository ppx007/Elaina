// dandanplay runtime tests cover ProviderGateway behavior and protocol mapping
// in one place so UI/playback tests can depend on normalized provider results.
// Add new wire cases here before exposing them through playback metadata.
import 'dart:convert';

import 'package:elaina/elaina.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime registers policy and routes match search comments and post',
      () async {
    final _RecordingGateway gateway =
        _RecordingGateway(proxyUrl: 'http://127.0.0.1:7890');
    const DandanplayMatchCandidate candidate = DandanplayMatchCandidate(
      animeId: DandanplayAnimeId('anime-1017'),
      episodeId: DandanplayEpisodeId('episode-1'),
      title: 'Elaina Episode 1',
      confidence: 0.98,
    );
    const DandanplayComment comment = DandanplayComment(
      timestamp: Duration(seconds: 12),
      text: '弹幕启动',
      mode: DandanplayCommentMode.scrolling,
    );
    final DandanplayProviderRuntime runtime = DandanplayProviderRuntime(
      gateway: gateway,
      matchCandidatesByFilename: <String, List<DandanplayMatchCandidate>>{
        'Elaina - 01.mkv': <DandanplayMatchCandidate>[candidate],
      },
      searchCandidates: const <DandanplayMatchCandidate>[candidate],
      commentsByEpisodeId: const <String, List<DandanplayComment>>{
        'episode-1': <DandanplayComment>[comment],
      },
    );

    final AcgProviderResult<List<DandanplayMatchCandidate>> match =
        await runtime.matchLocalMedia('  ELAINA - 01.mkv  ');
    expect(match, isA<AcgProviderSuccess<List<DandanplayMatchCandidate>>>());
    expect(gateway.registeredProviderId, dandanplayProviderId.value);
    expect(gateway.lastCacheKey, 'match:elaina - 01.mkv');
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkFirst);

    final AcgProviderResult<List<DandanplayMatchCandidate>> search =
        await runtime.search('episode');
    final List<DandanplayMatchCandidate> searchMatches =
        (search as AcgProviderSuccess<List<DandanplayMatchCandidate>>).value;
    expect(searchMatches.single.title, 'Elaina Episode 1');
    expect(gateway.lastCacheKey, 'search:episode');

    final AcgProviderResult<List<DandanplayComment>> comments =
        await runtime.commentsForEpisode(candidate.episodeId);
    expect(
      (comments as AcgProviderSuccess<List<DandanplayComment>>)
          .value
          .single
          .text,
      '弹幕启动',
    );
    expect(gateway.lastCacheKey, 'comments:episode-1');

    final AcgProviderResult<void> post = await runtime.postComment(
      const DandanplayCommentPost(
        episodeId: DandanplayEpisodeId('episode-1'),
        comment: DandanplayComment(
          timestamp: Duration(seconds: 13),
          text: 'posted',
          mode: DandanplayCommentMode.bottom,
        ),
      ),
    );
    expect(post, isA<AcgProviderSuccess<void>>());
    expect(gateway.lastCacheKey, startsWith('post-comment:episode-1:13000:'));
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkOnly);
    expect(
        runtime
            .deterministicCommentProvider?.postedComments.single.comment.text,
        'posted');
  });

  test('request helpers preserve provider id semantic keys and defaults', () {
    final ProviderRequestKey matchKey =
        dandanplayMatchRequestKey('  Episode 01.mkv  ');
    final ProviderRequestKey searchKey =
        dandanplaySearchRequestKey('  Elaina ');
    const DandanplayCommentPost post = DandanplayCommentPost(
      episodeId: DandanplayEpisodeId('episode-42'),
      comment: DandanplayComment(
        timestamp: Duration(milliseconds: 24001),
        text: 'hello',
        mode: DandanplayCommentMode.top,
      ),
    );
    final ProviderRequestKey commentsKey =
        dandanplayCommentsRequestKey(post.episodeId);
    final ProviderRequestKey postKey = dandanplayPostCommentRequestKey(post);
    final ProviderGatewayRequest<String> request =
        dandanplayGatewayRequest<String>(
      key: matchKey,
      load: () async => 'ok',
    );

    expect(matchKey.providerId.value, dandanplayProviderId.value);
    expect(matchKey.cacheKey, 'match:episode 01.mkv');
    expect(searchKey.cacheKey, 'search:elaina');
    expect(commentsKey.cacheKey, 'comments:episode-42');
    expect(postKey.cacheKey, startsWith('post-comment:episode-42:24001:'));
    expect(request.cachePolicy, ProviderCachePolicy.networkFirst);
    expect(
      request.deduplicationWindow,
      dandanplayRuntimeDeduplicationWindow,
    );
  });

  test('gateway failures normalize for match and comment operations', () async {
    final _FailingGateway throttled =
        _FailingGateway(ProviderFailureKind.throttled);
    final DeterministicDandanplayProvider provider =
        DeterministicDandanplayProvider(gateway: throttled);
    final AcgProviderResult<List<DandanplayMatchCandidate>> match =
        await provider.matchLocalMedia('missing.mkv');
    expect(
      (match as AcgProviderFailure<List<DandanplayMatchCandidate>>).kind,
      AcgProviderFailureKind.throttled,
    );

    final _FailingGateway retryable =
        _FailingGateway(ProviderFailureKind.retryable);
    final DeterministicDandanplayCommentProvider comments =
        DeterministicDandanplayCommentProvider(gateway: retryable);
    final AcgProviderResult<void> post = await comments.postComment(
      const DandanplayCommentPost(
        episodeId: DandanplayEpisodeId('episode-1'),
        comment: DandanplayComment(
          timestamp: Duration.zero,
          text: 'retry',
          mode: DandanplayCommentMode.scrolling,
        ),
      ),
    );
    expect(
      (post as AcgProviderFailure<void>).kind,
      AcgProviderFailureKind.retryable,
    );
  });

  test('disposed runtime normalizes operations and rejects direct dispatch',
      () async {
    final _RecordingGateway gateway =
        _RecordingGateway(proxyUrl: 'http://127.0.0.1:7890');
    final DandanplayProviderRuntime runtime = DandanplayProviderRuntime(
      gateway: gateway,
    );
    bool loaderExecuted = false;

    runtime.dispose();

    final AcgProviderResult<List<DandanplayMatchCandidate>> disposedMatch =
        await runtime.matchLocalMedia('after-dispose.mkv');
    expect(
      (disposedMatch as AcgProviderFailure<List<DandanplayMatchCandidate>>)
          .kind,
      AcgProviderFailureKind.unavailable,
    );
    final AcgProviderResult<List<DandanplayComment>> disposedComments =
        await runtime
            .commentsForEpisode(const DandanplayEpisodeId('episode-1'));
    expect(
      (disposedComments as AcgProviderFailure<List<DandanplayComment>>).kind,
      AcgProviderFailureKind.unavailable,
    );

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
              'Dandanplay provider runtime has been disposed.',
            ),
      ),
    );

    expect(loaderExecuted, isFalse);
    expect(gateway.registeredProviderId, isNull);
    expect(gateway.lastCacheKey, isNull);
  });

  test('domain runtime routes Dandanplay and leaves Bangumi optional',
      () async {
    const DandanplayMatchCandidate candidate = DandanplayMatchCandidate(
      animeId: DandanplayAnimeId('anime-domain'),
      episodeId: DandanplayEpisodeId('episode-domain'),
      title: 'Domain Dandanplay',
      confidence: 0.91,
    );
    final DandanplayAcgRuntime runtime = DandanplayAcgRuntime(
      gateway: _RecordingGateway(),
      matchCandidatesByFilename: const <String, List<DandanplayMatchCandidate>>{
        'domain.mkv': <DandanplayMatchCandidate>[candidate],
      },
      searchCandidates: const <DandanplayMatchCandidate>[candidate],
      commentsByEpisodeId: const <String, List<DandanplayComment>>{
        'episode-domain': <DandanplayComment>[
          DandanplayComment(
            timestamp: Duration(seconds: 2),
            text: 'domain-comment',
            mode: DandanplayCommentMode.scrolling,
          ),
        ],
      },
    );

    final AcgProviderResult<List<DandanplayMatchCandidate>> match =
        await runtime.controller.matchDandanplay('domain.mkv');
    expect(
      (match as AcgProviderSuccess<List<DandanplayMatchCandidate>>)
          .value
          .single
          .title,
      'Domain Dandanplay',
    );
    final AcgProviderResult<List<DandanplayComment>> comments = await runtime
        .controller
        .dandanplayComments(const DandanplayEpisodeId('episode-domain'));
    expect(
      (comments as AcgProviderSuccess<List<DandanplayComment>>)
          .value
          .single
          .text,
      'domain-comment',
    );
    final AcgProviderResult<BangumiSubject> bangumi = await runtime.controller
        .bangumiSubject(const BangumiSubjectId('missing'));
    expect(
      (bangumi as AcgProviderFailure<BangumiSubject>).kind,
      AcgProviderFailureKind.unavailable,
    );
  });

  test('Bangumi runtime can inject Dandanplay runtime without coupling failure',
      () async {
    const DandanplayMatchCandidate candidate = DandanplayMatchCandidate(
      animeId: DandanplayAnimeId('anime-injected'),
      episodeId: DandanplayEpisodeId('episode-injected'),
      title: 'Injected Dandanplay',
      confidence: 1,
    );
    final DandanplayProviderRuntime dandanplayRuntime =
        DandanplayProviderRuntime(
      gateway: _RecordingGateway(),
      matchCandidatesByFilename: const <String, List<DandanplayMatchCandidate>>{
        'injected.mkv': <DandanplayMatchCandidate>[candidate],
      },
    );
    final BangumiAcgRuntime bangumiRuntime = BangumiAcgRuntime(
      gateway: _RecordingGateway(),
      dandanplayProvider: dandanplayRuntime,
      dandanplayCommentProvider: dandanplayRuntime,
    );

    final AcgProviderResult<List<DandanplayMatchCandidate>> dandanplay =
        await bangumiRuntime.controller.matchDandanplay('injected.mkv');
    expect(
      (dandanplay as AcgProviderSuccess<List<DandanplayMatchCandidate>>)
          .value
          .single
          .animeId
          .value,
      'anime-injected',
    );

    final AcgProviderResult<BangumiSubject> missingBangumi =
        await bangumiRuntime.controller
            .bangumiSubject(const BangumiSubjectId('missing-bangumi'));
    expect(
      (missingBangumi as AcgProviderFailure<BangumiSubject>).kind,
      AcgProviderFailureKind.cachedMiss,
    );
  });

  test('concrete API provider maps match search comments and post via gateway',
      () async {
    final _RecordingGateway gateway =
        _RecordingGateway(proxyUrl: 'http://127.0.0.1:7890');
    final _FakeDandanplayTransport transport = _FakeDandanplayTransport(
      responses: <String, DandanplayApiResponse>{
        'POST /api/v2/match': const DandanplayApiResponse(
          statusCode: 200,
          body:
              '{"success":true,"isMatched":true,"matches":[{"animeId":1017,"episodeId":7,"animeTitle":"Concrete Anime","episodeTitle":"Episode 7"}]}',
        ),
        'GET /api/v2/search/episodes?anime=Concrete':
            const DandanplayApiResponse(
          statusCode: 200,
          body:
              '{"success":true,"hasMore":false,"animes":[{"animeId":1018,"animeTitle":"Search Anime","episodes":[{"episodeId":8,"episodeTitle":"Search Ep"}]}]}',
        ),
        'GET /api/v2/comment/7?from=0&withRelated=true&chConvert=0':
            const DandanplayApiResponse(
          statusCode: 200,
          body:
              '{"count":1,"comments":[{"cid":1,"p":"12.34,1,16777215,user","m":"hello"}]}',
        ),
        'POST /api/v2/comment/7': const DandanplayApiResponse(
          statusCode: 200,
          body: '{"success":true,"cid":99}',
        ),
      },
    );
    final DandanplayApiProvider provider = DandanplayApiProvider(
      gateway: gateway,
      client: DandanplayApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      credentialProvider: () async => const DandanplayApiCredentials(
        bearerToken: 'token-1',
        appId: 'app-1',
        appSecret: 'secret-1',
      ),
    );
    final DandanplayProviderRuntime runtime = DandanplayProviderRuntime(
      gateway: gateway,
      provider: provider,
      commentProvider: provider,
    );

    final AcgProviderResult<List<DandanplayMatchCandidate>> match =
        await runtime.matchLocalMedia('Concrete - 07.mkv');
    final DandanplayMatchCandidate matched =
        (match as AcgProviderSuccess<List<DandanplayMatchCandidate>>)
            .value
            .single;
    expect(matched.animeId.value, '1017');
    expect(matched.episodeId.value, '7');
    expect(matched.confidence, dandanplayExactMatchConfidence);
    expect(gateway.registeredProviderId, dandanplayProviderId.value);
    expect(gateway.lastCacheKey, 'match:concrete - 07.mkv');
    expect(gateway.lastNetworkPolicyUri,
        Uri.parse('https://api.test/api/v2/match'));
    final DandanplayApiRequest matchRequest = transport.requests.single;
    expect(matchRequest.method, 'POST');
    expect(matchRequest.uri.path, '/api/v2/match');
    expect(matchRequest.proxyUrl, 'http://127.0.0.1:7890');
    final Map<String, Object?> matchBody =
        jsonDecode(matchRequest.body!) as Map<String, Object?>;
    expect(matchBody['fileName'], 'Concrete - 07.mkv');
    expect(matchBody['matchMode'], dandanplayMatchModeFileNameOnly);

    final AcgProviderResult<List<DandanplayMatchCandidate>> search =
        await runtime.search('Concrete');
    expect(
      (search as AcgProviderSuccess<List<DandanplayMatchCandidate>>)
          .value
          .single
          .title,
      'Search Anime - Search Ep',
    );
    expect(gateway.lastCacheKey, 'search:concrete');
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://api.test/api/v2/search/episodes?anime=Concrete'),
    );
    expect(transport.requests.last.uri.path, '/api/v2/search/episodes');

    final AcgProviderResult<List<DandanplayComment>> comments =
        await runtime.commentsForEpisode(const DandanplayEpisodeId('7'));
    final DandanplayComment comment =
        (comments as AcgProviderSuccess<List<DandanplayComment>>).value.single;
    expect(comment.timestamp, const Duration(milliseconds: 12340));
    expect(comment.text, 'hello');
    expect(comment.mode, DandanplayCommentMode.scrolling);
    expect(comment.colorArgb, 16777215);
    expect(gateway.lastCacheKey, 'comments:7');
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse(
          'https://api.test/api/v2/comment/7?from=0&withRelated=true&chConvert=0'),
    );

    final AcgProviderResult<void> post = await runtime.postComment(
      const DandanplayCommentPost(
        episodeId: DandanplayEpisodeId('7'),
        comment: DandanplayComment(
          timestamp: Duration(milliseconds: 12340),
          text: 'posted',
          mode: DandanplayCommentMode.top,
          colorArgb: 255,
        ),
      ),
    );
    expect(post, isA<AcgProviderSuccess<void>>());
    expect(gateway.lastCacheKey, startsWith('post-comment:7:12340:'));
    expect(
      gateway.lastNetworkPolicyUri,
      Uri.parse('https://api.test/api/v2/comment/7'),
    );
    final DandanplayApiRequest postRequest = transport.requests.last;
    expect(postRequest.headers['authorization'], 'Bearer token-1');
    expect(postRequest.headers['X-AppId'], 'app-1');
    expect(postRequest.headers['X-AppSecret'], 'secret-1');
    final Map<String, Object?> postBody =
        jsonDecode(postRequest.body!) as Map<String, Object?>;
    expect(postBody['mode'], dandanplayRequestModeTop);
    expect(postBody['comment'], 'posted');
  });

  test('concrete API provider normalizes auth and API failures', () async {
    final _RecordingGateway gateway = _RecordingGateway();
    final _FakeDandanplayTransport transport = _FakeDandanplayTransport(
      responses: <String, DandanplayApiResponse>{
        'POST /api/v2/match': const DandanplayApiResponse(
          statusCode: 429,
          body: '{"success":false,"errorCode":429}',
        ),
        'GET /api/v2/search/episodes?anime=Malformed':
            const DandanplayApiResponse(statusCode: 200, body: '{bad'),
        'GET /api/v2/comment/missing?from=0&withRelated=true&chConvert=0':
            const DandanplayApiResponse(statusCode: 404, body: '{}'),
        'POST /api/v2/comment/7': const DandanplayApiResponse(
          statusCode: 401,
          body: '{"success":false}',
        ),
      },
    );
    final DandanplayApiProvider unauthenticated = DandanplayApiProvider(
      gateway: gateway,
      client: DandanplayApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
    );

    final AcgProviderResult<void> noCredentialPost =
        await unauthenticated.postComment(
      const DandanplayCommentPost(
        episodeId: DandanplayEpisodeId('7'),
        comment: DandanplayComment(
          timestamp: Duration.zero,
          text: 'posted',
          mode: DandanplayCommentMode.scrolling,
        ),
      ),
    );
    expect((noCredentialPost as AcgProviderFailure<void>).kind,
        AcgProviderFailureKind.unauthenticated);
    expect(transport.requests, isEmpty);

    final AcgProviderResult<List<DandanplayMatchCandidate>> throttled =
        await unauthenticated.matchLocalMedia('throttled.mkv');
    expect(
      (throttled as AcgProviderFailure<List<DandanplayMatchCandidate>>).kind,
      AcgProviderFailureKind.throttled,
    );

    final AcgProviderResult<List<DandanplayMatchCandidate>> malformed =
        await unauthenticated.search('Malformed');
    expect(
      (malformed as AcgProviderFailure<List<DandanplayMatchCandidate>>).kind,
      AcgProviderFailureKind.terminal,
    );

    final AcgProviderResult<List<DandanplayComment>> missing =
        await unauthenticated
            .commentsForEpisode(const DandanplayEpisodeId('missing'));
    expect((missing as AcgProviderFailure<List<DandanplayComment>>).kind,
        AcgProviderFailureKind.cachedMiss);

    final DandanplayApiProvider invalidCredential = DandanplayApiProvider(
      gateway: gateway,
      client: DandanplayApiClient(
        transport: transport,
        baseUri: Uri.parse('https://api.test'),
      ),
      credentialProvider: () async =>
          const DandanplayApiCredentials(bearerToken: 'bad-token'),
    );
    final AcgProviderResult<void> invalidPost =
        await invalidCredential.postComment(
      const DandanplayCommentPost(
        episodeId: DandanplayEpisodeId('7'),
        comment: DandanplayComment(
          timestamp: Duration.zero,
          text: 'posted',
          mode: DandanplayCommentMode.scrolling,
        ),
      ),
    );
    expect((invalidPost as AcgProviderFailure<void>).kind,
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
    ProviderGatewayRequest<T> request,
  ) {
    return Future<ProviderGatewayResponse<T>>.error(
      ProviderFailure(kind: kind, message: 'Injected gateway failure.'),
    );
  }
}

final class _FakeDandanplayTransport implements DandanplayApiTransport {
  _FakeDandanplayTransport({
    required Map<String, DandanplayApiResponse> responses,
  }) : _responses = responses;

  final Map<String, DandanplayApiResponse> _responses;
  final List<DandanplayApiRequest> requests = <DandanplayApiRequest>[];

  @override
  Future<DandanplayApiResponse> send(DandanplayApiRequest request) async {
    requests.add(request);
    final DandanplayApiResponse? response = _responses[_requestKey(request)];
    if (response != null) return response;
    return const DandanplayApiResponse(
      statusCode: 404,
      body: '{"success":false,"errorMessage":"missing fake response"}',
    );
  }

  String _requestKey(DandanplayApiRequest request) {
    final String query = request.uri.hasQuery ? '?${request.uri.query}' : '';
    return '${request.method} ${request.uri.path}$query';
  }
}
