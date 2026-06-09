import 'package:celesteria/celesteria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'runtime registers policy and looks up subject episode and search results',
      () async {
    final _RecordingGateway gateway = _RecordingGateway();
    final BangumiSubject subject = BangumiSubject(
      id: const BangumiSubjectId('subject-1017'),
      title: 'Celesteria',
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
    expect(matches.single.title, 'Celesteria');
    expect(gateway.lastCacheKey, 'subject-search:runtime');

    final AcgProviderResult<BangumiEpisode> episodeResult =
        await runtime.lookupEpisode(episode.id);
    expect((episodeResult as AcgProviderSuccess<BangumiEpisode>).value.title,
        'Bootstrap');
    expect(gateway.lastCacheKey, 'episode:episode-1');
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
    final ProviderGatewayRequest<String> request =
        bangumiGatewayRequest<String>(
      key: subjectKey,
      load: () async => 'ok',
    );

    expect(subjectKey.providerId.value, bangumiProviderId.value);
    expect(subjectKey.cacheKey, 'subject:42');
    expect(searchKey.cacheKey, 'subject-search:elaina');
    expect(episodeKey.cacheKey, 'episode:7');
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
          userId: 'user-1', expiresAt: now.add(const Duration(days: 1))),
      now: () => now,
    );

    final AcgProviderResult<BangumiAuthSession> sessionResult =
        await authenticated.currentSession();
    expect(
        (sessionResult as AcgProviderSuccess<BangumiAuthSession>).value.userId,
        'user-1');

    final AcgProviderResult<void> syncResult = await authenticated.syncProgress(
      const BangumiProgressUpdate(
        subjectId: BangumiSubjectId('subject-1017'),
        episodeId: BangumiEpisodeId('episode-1'),
        state: BangumiProgressState.watching,
      ),
    );
    expect(syncResult, isA<AcgProviderSuccess<void>>());

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
      ProviderGatewayRequest<T> request) async {
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
      ProviderGatewayRequest<T> request) {
    return Future<ProviderGatewayResponse<T>>.error(
      ProviderFailure(kind: kind, message: 'Injected gateway failure.'),
    );
  }
}
