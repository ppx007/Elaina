import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime registers policy and routes match search comments and post',
      () async {
    final _RecordingGateway gateway = _RecordingGateway();
    const DandanplayMatchCandidate candidate = DandanplayMatchCandidate(
      animeId: DandanplayAnimeId('anime-1017'),
      episodeId: DandanplayEpisodeId('episode-1'),
      title: 'Celesteria Episode 1',
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
        'Celesteria - 01.mkv': <DandanplayMatchCandidate>[candidate],
      },
      searchCandidates: const <DandanplayMatchCandidate>[candidate],
      commentsByEpisodeId: const <String, List<DandanplayComment>>{
        'episode-1': <DandanplayComment>[comment],
      },
    );

    final AcgProviderResult<List<DandanplayMatchCandidate>> match =
        await runtime.matchLocalMedia('  CELESTERIA - 01.mkv  ');
    expect(match, isA<AcgProviderSuccess<List<DandanplayMatchCandidate>>>());
    expect(gateway.registeredProviderId, dandanplayProviderId.value);
    expect(gateway.lastCacheKey, 'match:celesteria - 01.mkv');
    expect(gateway.lastCachePolicy, ProviderCachePolicy.networkFirst);

    final AcgProviderResult<List<DandanplayMatchCandidate>> search =
        await runtime.search('episode');
    final List<DandanplayMatchCandidate> searchMatches =
        (search as AcgProviderSuccess<List<DandanplayMatchCandidate>>).value;
    expect(searchMatches.single.title, 'Celesteria Episode 1');
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
        runtime.commentProvider.postedComments.single.comment.text, 'posted');
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
    final _RecordingGateway gateway = _RecordingGateway();
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
}

final class _RecordingGateway implements ProviderGateway {
  final DeterministicStorageFoundation _storage =
      DeterministicStorageFoundation();
  String? registeredProviderId;
  String? lastCacheKey;
  ProviderCachePolicy? lastCachePolicy;

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
    return ProviderGatewayResponse<T>(
      value: await request.load(),
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
